import json
import base64
import boto3

# Constants
SOCKET_PATH = "/run/container_launcher/teeserver.sock"
TOKEN_ENDPOINT = "http://localhost/v1/token"
CONTENT_TYPE = "application/json"
AUDIENCE = "https://meal.corp"
ROLE_ARN = "arn:aws:iam::882493070157:role/confidential-space-role"
AWS_KMS_KEY_ID = "98ac6406-43e1-488c-b9ae-6fee66d13c4a"
TOKEN_TYPE = "LIMITED_AWS"
AWS_REGION = "eu-west-1"
AWS_SESSION_NAME = "integration_test"
BUCKET_NAME = "confidential-space-bucket"
OBJECT_KEY = "primus_customer_list_enc"

# Function to get a custom token
def get_custom_token(body):
    try:
        import httpx

        transport = httpx.HTTPTransport(uds=SOCKET_PATH)
        client = httpx.Client(transport=transport)
        response = client.post(TOKEN_ENDPOINT, headers={"Content-Type": CONTENT_TYPE}, json=body)
        print(f"Status_code: {response.status_code}")
        return response.text
    except Exception as e:
        print(f"Error retrieving custom token: {e}")
        raise

# Function to get a AWS STS token
def get_aws_token(token):
    try:
        # Create a session with the specified profile (if provided)
        sts_client = boto3.client('sts', region_name=AWS_REGION)
        response = sts_client.assume_role_with_web_identity(
            RoleArn=ROLE_ARN,
            RoleSessionName=AWS_SESSION_NAME,
            WebIdentityToken=token,
        )
        temp_credentials = response["Credentials"]
        print(f"Assumed role and got temporary credentials.")
        return temp_credentials
    except ClientError as error:
        print(
            f"Couldn't assume role. Here's why: "
            f"{error.response['Error']['Message']}"
        )
        raise

# Function to fetch blob from S3
def fetch_blob_from_s3(aws_session):

    # List objects in the bucket
    try:
        # Create an S3 client with the new session
        s3_client = aws_session.client('s3')
        
        # Read the encrypted object from S3
        response = s3_client.get_object(Bucket=BUCKET_NAME, Key=OBJECT_KEY)
        ciphertext_blob = base64.b64decode(response['Body'].read())
        return ciphertext_blob
    except Exception as e:
        print(f"Error reading objects: {e}")
        raise

# Function to decrypt ciphertext blob
def decrypt_ciphertext_blob(aws_session, ciphertext_blob):
    try:
        # Create a KMS client with the new session
        kms_client = aws_session.client('kms', region_name=AWS_REGION)

        # Decrypt the ciphertext using KMS
        decrypted_result = kms_client.decrypt(
            CiphertextBlob=ciphertext_blob,
            KeyId=AWS_KMS_KEY_ID  # Optional if the key ID is in the ciphertext
        )

        # Decode the plaintext from bytes to string
        plaintext = decrypted_result['Plaintext'].decode('utf-8')        
        print(f"Decrypt Succeeded: {plaintext}")
        return plaintext
    except Exception as e:
        print(f"Error decrypting object: {e}")
        raise

if __name__ == "__main__":
    print("-" * 88)
    print(f"Welcome to the IAM create user and assume role demo.")
    print("-" * 88)
    try:
        # Get LIMITED_AWS token
        body = {
            "audience": AUDIENCE,
            "token_type": TOKEN_TYPE,
        }
        token = get_custom_token(body)
        
        temp_credentials = get_aws_token(token)

        # Create a new session with the temporary credentials
        aws_session = boto3.Session(
            aws_access_key_id=temp_credentials['AccessKeyId'],
            aws_secret_access_key=temp_credentials['SecretAccessKey'],
            aws_session_token=temp_credentials['SessionToken']
        )
    
        ciphertext_blob = fetch_blob_from_s3(aws_session)    
        decrypt_ciphertext_blob(aws_session, ciphertext_blob)
    except Exception:
        print("Something went wrong!")
    finally:
        print("Thanks for watching!")