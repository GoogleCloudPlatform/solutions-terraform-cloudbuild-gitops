#!/bin/bash

PARENT_DIR=$(dirname ${PWD})

cat << 'EOF' > ${PARENT_DIR}/src/workload.go
// Simple CLI based Go application which provides following commands.
//
//		count-location : Counts number of customers from given geographic location.
//	          Usage: count-location <location> <output cloud storage bucket URI>
//		list-common-customers : Finds the list of common customers between Primus and Secundus banks.
//						Usage: list-common-customers <output cloud storage bucket URI>"
package main

import (
  "bytes"
  "context"
  "errors"
  "encoding/csv"
  "fmt"
  "hash/crc32"
  "os"
  "regexp"
  "strings"
  "encoding/base64"
  "flag"
  "io/ioutil"

  kmspb "cloud.google.com/go/kms/apiv1/kmspb"
  "github.com/google/logger"
  "google.golang.org/protobuf/types/known/wrapperspb"

  "github.com/google/subcommands"
  "google.golang.org/api/option"

  kms "cloud.google.com/go/kms/apiv1"
  storage "cloud.google.com/go/storage"
)

const (
	primusBucketName                   = "PRIMUS_INPUT_STORAGE_BUCKET"
	primusDataPath                     = "enc_primus_customer_list.csv"
	primusKeyName                      = "projects/PRIMUS_PROJECT_ID/locations/global/keyRings/PRIMUS_ENC_KEYRING/cryptoKeys/PRIMUS_ENC_KEY"
	primusWIPProviderName              = "projects/PRIMUS_PROJECT_NUMBER/locations/global/workloadIdentityPools/PRIMUS_WORKLOAD_IDENTITY_POOL/providers/PRIMUS_WIP_PROVIDER"
	primusKeyAccessServiceAccountEmail = "PRIMUS_SERVICE_ACCOUNT@PRIMUS_PROJECT_ID.iam.gserviceaccount.com"

	secundusBucketName                   = "SECUNDUS_INPUT_STORAGE_BUCKET"
	secundusDataPath                     = "enc_secundus_customer_list.csv"
	secundusKeyName                      = "projects/SECUNDUS_PROJECT_ID/locations/global/keyRings/SECUNDUS_ENC_KEYRING/cryptoKeys/SECUNDUS_ENC_KEY"
	secundusWIPProviderName              = "projects/SECUNDUS_PROJECT_NUMBER/locations/global/workloadIdentityPools/SECUNDUS_WORKLOAD_IDENTITY_POOL/providers/SECUNDUS_WIP_PROVIDER"
	secundusKeyAccessServiceAccountEmail = "SECUNDUS_SERVICE_ACCOUNT@SECUNDUS_PROJECT_ID.iam.gserviceaccount.com"
)

const credentialConfig = `{
"type": "external_account",
"audience": "//iam.googleapis.com/%s",
"subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
"token_url": "https://sts.googleapis.com/v1/token",
"credential_source": {
  "file": "/run/container_launcher/attestation_verifier_claims_token"
},
"service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/%s:generateAccessToken"
}`

func crc32c(data []byte) uint32 {
	t := crc32.MakeTable(crc32.Castagnoli)
	return crc32.Checksum(data, t)
}

func decryptFile(ctx context.Context, keyName, trustedServiceAccountEmail, wipProviderName string, encryptedData []byte) ([]byte, error) {
	credentialConfig := fmt.Sprintf(credentialConfig, wipProviderName, trustedServiceAccountEmail)
	kmsClient, err := kms.NewKeyManagementClient(ctx, option.WithCredentialsJSON([]byte(credentialConfig)))
	if err != nil {
		return nil, fmt.Errorf("creating a new KMS client with federated credentials: %w", err)
	}

	decryptRequest := &kmspb.DecryptRequest{
		Name:             keyName,
		Ciphertext:       encryptedData,
		CiphertextCrc32C: wrapperspb.Int64(int64(crc32c(encryptedData))),
	}

	decryptResponse, err := kmsClient.Decrypt(ctx, decryptRequest)
	if err != nil {
		return nil, fmt.Errorf("could not decrypt ciphertext: %w", err)
	}
	if int64(crc32c(decryptResponse.Plaintext)) != decryptResponse.PlaintextCrc32C.Value {
		return nil, fmt.Errorf("decrypt response corrupted in-transit")
	}

	return decryptResponse.Plaintext, nil
}

type tableInput struct {
	BucketName                   string
	DataPath                     string
	KeyName                      string
	KeyAccessServiceAccountEmail string
	WIPProviderName              string
}

func readInTable(ctx context.Context, tableInfo tableInput) ([][]string, error) {
	storageClient, err := storage.NewClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("could not create storage client with default credentials: %w", err)
	}
	bucketHandle := storageClient.Bucket(tableInfo.BucketName)
	objectHandle := bucketHandle.Object(tableInfo.DataPath)

	objectReader, err := objectHandle.NewReader(ctx)
	if err != nil {
		return nil, fmt.Errorf("could not read in gs://%v/%v: %w", tableInfo.BucketName, tableInfo.DataPath, err)
	}
	defer objectReader.Close()
    encodedData, err := ioutil.ReadAll(objectReader)
	if err != nil {
		return nil, fmt.Errorf("could not read in gs://%v/%v: %w", tableInfo.BucketName, tableInfo.DataPath, err)
	}
    encryptedData, err := base64.StdEncoding.DecodeString(string(encodedData))
    if err != nil {
        return nil, fmt.Errorf("could not decode gs://%v/%v: %w", tableInfo.BucketName, tableInfo.DataPath, err)
    }
	decryptedData, err := decryptFile(ctx, tableInfo.KeyName, tableInfo.KeyAccessServiceAccountEmail, tableInfo.WIPProviderName, encryptedData)
	if err != nil {
		return nil, fmt.Errorf("could not decrypt gs://%v/%v: %w", tableInfo.BucketName, tableInfo.DataPath, err)
	}
	csvReader := csv.NewReader(bytes.NewReader(decryptedData))
	customerData, err := csvReader.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("could not read in gs://%v/%v: %w", tableInfo.BucketName, tableInfo.DataPath, err)
	}
	return customerData, nil
}

func readInPrimusTable(ctx context.Context) ([][]string, error) {
	primusTableInfo := tableInput{
		BucketName:                   primusBucketName,
		DataPath:                     primusDataPath,
		KeyName:                      primusKeyName,
		KeyAccessServiceAccountEmail: primusKeyAccessServiceAccountEmail,
		WIPProviderName:              primusWIPProviderName,
	}
	return readInTable(ctx, primusTableInfo)
}

func readInSecundusTable(ctx context.Context) ([][]string, error) {
	secundusTableInfo := tableInput{
		BucketName:                   secundusBucketName,
		DataPath:                     secundusDataPath,
		KeyName:                      secundusKeyName,
		KeyAccessServiceAccountEmail: secundusKeyAccessServiceAccountEmail,
		WIPProviderName:              secundusWIPProviderName,
	}
	return readInTable(ctx, secundusTableInfo)
}

func writeErrorToBucket(outputWriter *storage.Writer, outputBucket, outputPath string, err error) {
	// Writes errors reading in protected data to the results bucket.
	// This becomes relevant when demonstrating the failure case.
	if _, err = outputWriter.Write([]byte(fmt.Sprintf("Error reading in protected data: %v", err))); err != nil {
		logger.Errorf("Could not write to gs://%v/%v: %v", outputBucket, outputPath, err)
	}
	if err = outputWriter.Close(); err != nil {
		logger.Errorf("Could not write to gs://%v/%v: %v", outputBucket, outputPath, err)
	}
}

type countLocationCmd struct{}

func (*countLocationCmd) Name() string     { return "count-location" }
func (*countLocationCmd) Synopsis() string { return "counts the number of users at the given location" }
func (*countLocationCmd) Usage() string {
	return "Usage: second_workload count-location <location> <output_bucket> <output_path>"
}
func (*countLocationCmd) SetFlags(_ *flag.FlagSet) {}
func (*countLocationCmd) Execute(ctx context.Context, f *flag.FlagSet, _ ...interface{}) subcommands.ExitStatus {
	if f.NArg() != 2 {
		logger.Errorf("Not enough arguments (expected location and output object URI)")
		return subcommands.ExitUsageError
	}

	outputURI := f.Arg(1)
	re := regexp.MustCompile("gs://([^/]*)/(.*)")
	matches := re.FindStringSubmatch(outputURI)
	if matches == nil || matches[0] != outputURI || len(matches) != 3 {
		logger.Errorf("Second argument should be in the format gs://bucket/object")
		return subcommands.ExitUsageError
	}
	outputBucket := matches[1]
	outputPath := matches[2]
	client, err := storage.NewClient(ctx)
	if err != nil {
		logger.Errorf("Error creating storage client with application default credentials: %v", err)
		return subcommands.ExitFailure
	}
	outputWriter := client.Bucket(outputBucket).Object(outputPath).NewWriter(ctx)

	customerData, err := readInPrimusTable(ctx)
	if err != nil {
		// Writes errors reading in the primus bank data to the results bucket.
		// This becomes relevant when demonstrating the failure case.
		_, err = outputWriter.Write([]byte(fmt.Sprintf("Error reading in Primus Bank data: %v", err)))
		if err != nil {
			logger.Errorf("Could not write to %v: %v", outputURI, err)
		}
		if err = outputWriter.Close(); err != nil {
			logger.Errorf("Could not write to %v: %v", outputURI, err)
		}
		return subcommands.ExitFailure
	}

	location := strings.ToLower(f.Arg(0))
	count := 0
	if location == "-" {
		count = len(customerData)
	} else {
		for _, line := range customerData {
			if strings.ToLower(line[2]) == location {
				count++
			}
		}
	}

	_, err = outputWriter.Write([]byte(fmt.Sprintf("%d", count)))
	if err != nil {
		logger.Errorf("Could not write to %v: %v", outputURI, err)
		return subcommands.ExitFailure
	}

	if err = outputWriter.Close(); err != nil {
		logger.Errorf("Could not write to %v: %v", outputURI, err)
		return subcommands.ExitFailure
	}

	return subcommands.ExitSuccess
}

func commonCustomers(primusDataset, inputDataset [][]string) ([]string, error) {
	var common []string
	set := make(map[string]bool)
	for _, entry := range primusDataset {
		if len(entry) != 3 {
			return nil, errors.New("invalid entry in primusDataset, must be of length 3 in the form (id, name, location)")
		}
		set[entry[1]] = true
	}

	for _, entry := range inputDataset {
		if len(entry) != 3 {
			return nil, errors.New("invalid entry in inputDataset, must be of length 3 in the form (id, name, location)")
		}
		if set[entry[1]] {
			common = append(common, entry[1])
		}
	}
	return common, nil
}

type listCommonCustomersCmd struct{}

func (*listCommonCustomersCmd) Name() string { return "list-common-customers" }
func (*listCommonCustomersCmd) Synopsis() string {
	return "lists the customers in common between two lists"
}
func (*listCommonCustomersCmd) Usage() string {
	return "Usage: list-common-customers> <output cloud storage bucket URI>"
}
func (*listCommonCustomersCmd) SetFlags(_ *flag.FlagSet) {}
func (*listCommonCustomersCmd) Execute(ctx context.Context, f *flag.FlagSet, _ ...interface{}) subcommands.ExitStatus {
	if f.NArg() != 1 {
		logger.Errorf("Not enough arguments (output object URI)")
		return subcommands.ExitUsageError
	}

	re := regexp.MustCompile("gs://([^/]*)/(.*)")

	outputURI := f.Arg(0)
	outputMatches := re.FindStringSubmatch(outputURI)
	if outputMatches == nil || outputMatches[0] != outputURI || len(outputMatches) != 3 {
		logger.Errorf("Fifth argument should be in the format gs://bucket/object")
		return subcommands.ExitUsageError
	}
	outputBucket := outputMatches[1]
	outputPath := outputMatches[2]
	client, err := storage.NewClient(ctx)
	if err != nil {
		logger.Errorf("Error creating storage client with application default credentials: %v", err)
		return subcommands.ExitFailure
	}
	outputWriter := client.Bucket(outputBucket).Object(outputPath).NewWriter(ctx)

	primusCustomerData, err := readInPrimusTable(ctx)
	if err != nil {
		writeErrorToBucket(outputWriter, outputBucket, outputPath, err)
		return subcommands.ExitFailure
	}

	secundusCustomerData, err := readInSecundusTable(ctx)
	if err != nil {
		writeErrorToBucket(outputWriter, outputBucket, outputPath, err)
		return subcommands.ExitFailure
	}

	common, err := commonCustomers(primusCustomerData, secundusCustomerData)
	if err != nil {
		writeErrorToBucket(outputWriter, outputBucket, outputPath, err)
		return subcommands.ExitFailure
	}

	var result string
	if len(common) > 0 {
		result = strings.Join(common, "\n")
	} else {
		result = "No common customers found"
	}
	_, err = outputWriter.Write([]byte(result))
	if err != nil {
		logger.Errorf("Could not write to gs://%v/%v: %v", outputBucket, outputPath, err)
		return subcommands.ExitFailure
	}

	if err = outputWriter.Close(); err != nil {
		logger.Errorf("Could not write to gs://%v/%v: %v", outputBucket, outputPath, err)
		return subcommands.ExitFailure
	}

	return subcommands.ExitSuccess
}

func main() {
	flag.Parse()
	ctx := context.Background()

	subcommands.Register(&countLocationCmd{}, "")
	subcommands.Register(&listCommonCustomersCmd{}, "")

	os.Exit(int(subcommands.Execute(ctx)))
}

EOF