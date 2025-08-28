// package main is a test workload that will print out the success status of an AWS decrypt operation.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/credentials/stscreds"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/kms"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/sts"
)

var (
	socketPath     = "/run/container_launcher/teeserver.sock"
	tokenEndpoint  = "http://localhost/v1/token"
	contentType    = "application/json"
	audience       = "https://meal.corp"
	roleARN        = "arn:aws:iam::882493070157:role/confidential-space-role"
	awsKmsKeyID    = "arn:aws:kms:eu-west-1:882493070157:key/98ac6406-43e1-488c-b9ae-6fee66d13c4a"
	tokenPath      = "./token"
	tokenType      = "LIMITED_AWS"
	awsRegion      = "eu-west-1"
	awsSessionName = "integration_test"
)

type tokenRequest struct {
	Audience  string   `json:"audience"`
	Nonces    []string `json:"nonces"`
	TokenType string   `json:"token_type"`
}

func getCustomTokenBytes(body string) (string, error) {
	httpClient := http.Client{
		Transport: &http.Transport{
			// Set the DialContext field to a function that creates
			// a new network connection to a Unix domain socket
			DialContext: func(_ context.Context, _, _ string) (net.Conn, error) {
				return net.Dial("unix", socketPath)
			},
		},
	}

	resp, err := httpClient.Post(tokenEndpoint, contentType, strings.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("failed to get raw custom token response: %w", err)
	}

	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("failed to get a valid attestation token, status code: %v", resp.StatusCode)
	}

	tokenbytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read custom token body: %w", err)
	}

	return string(tokenbytes), nil
}

func writeTokenToPath(token string, tokenPath string) {
	os.WriteFile(tokenPath, []byte(token), 0644)
}

func fetchBlobFromS3(s *session.Session, provider credentials.Provider) ([]byte, error) {
	myBucket := "confidential-space-bucket"
	myString := "primus_customer_list_enc"

	client := s3.New(s, &aws.Config{
		Credentials: credentials.NewCredentials(provider),
	})

	input := &s3.GetObjectInput{
		Bucket: aws.String(myBucket),
		Key:    aws.String(myString),
	}
	result, err := client.GetObject(input)
	if err != nil {
		return nil, err
	}

	buf := new(strings.Builder)
	n, err := io.Copy(buf, result.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read from result response body: %w", err)
	}

	fmt.Printf("downloaded blob from AWS at location '%v/%v'\n", myBucket, myString)
	fmt.Printf("blob length: %v bytes\n\n", n)

	return []byte(buf.String()), nil
}

func main() {
	// Get LIMITED_AWS token
	body := tokenRequest{
		Audience:  audience,
		TokenType: tokenType,
	}

	val, err := json.Marshal(body)
	if err != nil {
		err = fmt.Errorf("failed to marshal custom request into a request body. Attempted to marshal '%v', got err: %w", body, err)
		panic(err)
	}

	token, err := getCustomTokenBytes(string(val))
	if err != nil {
		panic(err)
	}

	fmt.Println("Token recieved: %v", token)

	// AWS Module requires a token path for some reason
	writeTokenToPath(token, tokenPath)

	sess, _ := session.NewSession(&aws.Config{
		Region: aws.String(awsRegion)})
	sts := sts.New(sess)

	// Assume the role with the token we just wrote to disk
	roleProvider := stscreds.NewWebIdentityRoleProviderWithOptions(sts, roleARN, awsSessionName, stscreds.FetchTokenPath(tokenPath))

	// Download data from AWS
	blobFromS3, err := fetchBlobFromS3(sess, roleProvider)
	if err != nil {
		fmt.Printf("failed to fetch blob from S3: %v\n", err)
		return
	}

	// Call Decrypt
	svc := kms.New(sess, &aws.Config{
		Credentials: credentials.NewCredentials(roleProvider),
	})
	input := &kms.DecryptInput{
		// KeyId is optional for symmetric key decryption, but is a best practice
		KeyId:          aws.String(awsKmsKeyID),
		CiphertextBlob: []byte(blobFromS3),
	}

	result, err := svc.Decrypt(input)
	if err != nil {
		fmt.Printf("Decrypt Failed: %v\n", err)
		return
	}

	fmt.Printf("Decrypt Succeeded: %v\n", result)
}
