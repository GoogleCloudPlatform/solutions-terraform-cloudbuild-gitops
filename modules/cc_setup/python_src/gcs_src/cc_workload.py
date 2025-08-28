import base64
import csv
import crcmod
import io
import re
import sys
import json
import os
from google.oauth2 import service_account
from google.cloud import kms, storage

# Constants for Primus Bank
primus_bucket_name = "primus-bank-421307-input-bucket"
primus_data_path = "enc_primus_customer_list.csv"
primus_key_name = "projects/primus-bank-421307/locations/us-central1/keyRings/primus-bank-421307-sym-enc-kr/cryptoKeys/primus-bank-421307-sym-enc-key"
primus_key_access_service_account_email = "primus-bank-421307-sa@primus-bank-421307.iam.gserviceaccount.com"
primus_wip_provider_name = "projects/402390551076/locations/global/workloadIdentityPools/primus-bank-421307-pool/providers/primus-bank-421307-provider"

# Constants for Secundus Bank
secundus_bucket_name = "secundus-bank-421307-input-bucket"
secundus_data_path = "enc_secundus_customer_list.csv"
secundus_key_name = "projects/secundus-bank-421307/locations/us-central1/keyRings/secundus-bank-421307-sym-enc-kr/cryptoKeys/secundus-bank-421307-sym-enc-key"
secundus_key_access_service_account_email = "secundus-bank-421307-sa@secundus-bank-421307.iam.gserviceaccount.com"
secundus_wip_provider_name = "projects/52138078815/locations/global/workloadIdentityPools/secundus-bank-421307-pool/providers/secundus-bank-421307-provider"

# Credential configuration for Workload Identity Federation
credential_config = """
{{
"type": "external_account",
"audience": "//iam.googleapis.com/{}",
"subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
"token_url": "https://sts.googleapis.com/v1/token",
"credential_source": {{
"file": "/run/container_launcher/attestation_verifier_claims_token"
}},
"service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{}:generateAccessToken"
}}
"""

def crc32c(data: bytes) -> int:
    crc32c_fun = crcmod.predefined.mkPredefinedCrcFun("crc-32c")
    return crc32c_fun(data)

def decrypt_file(key_name, trusted_service_account_email, wip_provider_name, encrypted_data):
    print("Decrypts the given encrypted data using the provided KMS key.")
    try:
        # Construct the credential configuration for Workload Identity Federation
        credential_config_str = credential_config.format(wip_provider_name, trusted_service_account_email)

        try:
            # Parse the JSON string to ensure it's valid
            credential_config_json = json.loads(credential_config_str) 
        
            with open("cred.json", 'w') as f:
              json.dump(credential_config_json, f, indent=4)  # indent for pretty printing
            print(f"JSON data written to cred.json")
        
        except json.JSONDecodeError as e:
            raise RuntimeError(f"Error decoding JSON string: {e}")

        # Create a KMS client with the federated credentials
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "cred.json"
        kms_client = kms.KeyManagementServiceClient()

        # Build the decrypt request
        decrypt_request = {
            "name": key_name,
            "ciphertext": encrypted_data,
            "ciphertext_crc32c": crc32c(encrypted_data),
        }

        # Call the KMS API to decrypt the data
        decrypt_response = kms_client.decrypt(request=decrypt_request)

        # Verify the integrity of the decrypted data
        if crc32c(decrypt_response.plaintext) != decrypt_response.plaintext_crc32c:
            raise ValueError("Decrypt response corrupted in-transit")

        del os.environ['GOOGLE_APPLICATION_CREDENTIALS'] 

        return decrypt_response.plaintext
    except Exception as e:
        raise RuntimeError(f"Could not decrypt ciphertext: {e}")

def read_in_table(table_info):
    print("Reads and decrypts the CSV data from the specified Google Cloud Storage bucket.")
    try:

        # Create a Storage client
        storage_client = storage.Client()

        # Get the bucket and object handles
        bucket_handle = storage_client.bucket(table_info["bucket_name"])
        object_handle = bucket_handle.blob(table_info["data_path"])

        # Download the encrypted data from the bucket
        encoded_data = object_handle.download_as_string()
        encrypted_data = base64.b64decode(encoded_data)

        # Decrypt the data using the KMS key
        decrypted_data = decrypt_file(
            table_info["key_name"],
            table_info["key_access_service_account_email"],
            table_info["wip_provider_name"],
            encrypted_data,
        )

        # Parse the decrypted CSV data
        csv_reader = csv.reader(io.StringIO(decrypted_data.decode()))
        customer_data = list(csv_reader)

        return customer_data
    except Exception as e:
        raise RuntimeError(f"Could not read and decrypt data: {e}")

def read_in_primus_table():
    print("Reads and decrypts the Primus Bank customer data.")
    
    primus_table_info = {
        "bucket_name": primus_bucket_name,
        "data_path": primus_data_path,
        "key_name": primus_key_name,
        "key_access_service_account_email": primus_key_access_service_account_email,
        "wip_provider_name": primus_wip_provider_name,
    }
    return read_in_table(primus_table_info)

def read_in_secundus_table():
    print("Reads and decrypts the Secundus Bank customer data.")
    secundus_table_info = {
        "bucket_name": secundus_bucket_name,
        "data_path": secundus_data_path,
        "key_name": secundus_key_name,
        "key_access_service_account_email": secundus_key_access_service_account_email,
        "wip_provider_name": secundus_wip_provider_name,
    }
    return read_in_table(secundus_table_info)

def write_error_to_bucket(output_bucket, output_path, error_message):
    print("Writes the specified error message to the given Google Cloud Storage bucket.")
    try:
        # Create a Storage client
        storage_client = storage.Client()

        # Get the bucket and object handles
        bucket_handle = storage_client.bucket(output_bucket)
        object_handle = bucket_handle.blob(output_path)

        # Upload the error message to the bucket
        object_handle.upload_from_string(error_message)
    except Exception as e:
        raise RuntimeError(f"Could not write error message to bucket: {e}")

def count_location(location, output_uri):
    print("Counts the number of customers at the given location in the Primus Bank data.")
    try:
        # Parse the output URI
        match = re.match(r"gs://([^/]*)/(.*)", output_uri)
        if not match:
            raise ValueError("Invalid output URI format")
        output_bucket, output_path = match.groups()

        # Read and decrypt the Primus Bank customer data
        customer_data = read_in_primus_table()

        # Count the customers at the specified location
        count = 0
        if location == "-":
            count = len(customer_data)
        else:
            for line in customer_data:
                if line[2].lower() == location.lower():
                    count += 1

        # Upload the count to the specified Google Cloud Storage bucket
        write_error_to_bucket(output_bucket, output_path, str(count))

    except Exception as e:
        # Write any errors encountered to the output bucket
        write_error_to_bucket(output_bucket, output_path, f"Error: {e}")

def common_customers(output_uri):
    print("Finds the common customers between Primus and Secundus bank data.")
    try:
        # Parse the output URI
        match = re.match(r"gs://([^/]*)/(.*)", output_uri)
        if not match:
            raise ValueError("Invalid output URI format")
        output_bucket, output_path = match.groups()

        # Read and decrypt the customer data for both banks
        primus_customer_data = read_in_primus_table()
        secundus_customer_data = read_in_secundus_table()

        # Create a set of names from the Primus data
        primus_names = {line[1] for line in primus_customer_data}

        # Find the common names in the Secundus data
        common = [line[1] for line in secundus_customer_data if line[1] in primus_names]

        # Format the result
        result = "\n".join(common) if common else "No common customers found"

        # Upload the result to the specified Google Cloud Storage bucket
        write_error_to_bucket(output_bucket, output_path, result)

    except Exception as e:
        # Write any errors encountered to the output bucket
        write_error_to_bucket(output_bucket, output_path, f"Error: {e}")

if __name__ == "__main__":

    args = sys.argv[1:]
    
    if args[0] == "count-location":
        if len(args) != 3:
            print("Usage: python main.py count-location <location> <output_uri>")
        else:
            location = args[1]
            output_uri = args[2]
            count_location(location, output_uri)
    elif args[0] == "list-common-customers":
        if len(args) != 2:
            print("Usage: python main.py list-common-customers <output_uri>")
        else:
            output_uri = args[1]
            common_customers(output_uri)
    else:
        print("Invalid command")