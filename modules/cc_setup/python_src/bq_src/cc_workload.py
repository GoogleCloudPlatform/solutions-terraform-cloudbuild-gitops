import os
import re
import sys
import json
from google.oauth2 import service_account
from google.cloud import storage, bigquery

# Constants for Primus Bank
primus_project_id = "primus-bank-421307"
primus_service_account_email = "primus-bank-421307-sa@primus-bank-421307.iam.gserviceaccount.com"
primus_wip_provider_name = "projects/402390551076/locations/global/workloadIdentityPools/primus-bank-421307-pool/providers/primus-bank-421307-provider"

# Constants for Secundus Bank
secundus_project_id = "secundus-bank-421307"
secundus_service_account_email = "secundus-bank-421307-sa@secundus-bank-421307.iam.gserviceaccount.com"
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

def read_in_bq(project_id, query_info, wip_provider_name, trusted_service_account_email):
    print("Reads and decrypts customer data from the specified Google Cloud BigQuery table.")
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

        # Construct a BigQuery client with the federated credentials
        client = bigquery.Client(project=project_id)

        query_results = client.query_and_wait(query_info.replace("project_id", project_id))  # Make an API request.
        
        del os.environ['GOOGLE_APPLICATION_CREDENTIALS'] 
        
        return query_results
    except Exception as e:
        raise RuntimeError(f"Could not read and decrypt data: {e}")

def read_keyset(project_id):
    print("Reads and decrypts the KEYSET data from the specified Google Cloud Storage bucket.")
    try:

        # Create a Storage client
        storage_client = storage.Client()

        # Get the bucket and object handles
        bucket = storage_client.bucket(f"{project_id}-input-bucket")
        blob = bucket.blob(f"{project_id.split('-')[0]}-wrapped-keyset")

        return blob.download_as_text()
    except Exception as e:
        raise RuntimeError(f"Could not read keyset: {e}")

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
        query_info = """
            SELECT COUNT(enc_name) as total_people
            FROM `project_id.ccdemo_dataset.enc-customer-list`
            WHERE city = '{location}'
        """.format(location=location)
        
        query_results = read_in_bq(primus_project_id, query_info, primus_wip_provider_name, primus_service_account_email)

        for row in query_results:
            output_string = str(row["total_people"])

        # Upload the count to the specified Google Cloud Storage bucket
        write_error_to_bucket(output_bucket, output_path, output_string)

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
        query_info = """
            SELECT DETERMINISTIC_DECRYPT_STRING(
              KEYS.KEYSET_CHAIN('gcp-kms://projects/project_id/locations/us-central1/keyRings/project_id-sym-enc-kr/cryptoKeys/project_id-sym-enc-key',
              {keyset}),
              enc_name,
              '') as name
            FROM `project_id.ccdemo_dataset.enc-customer-list`
        """
        
        primus_customer_data = read_in_bq(primus_project_id, query_info.format(keyset=read_keyset(primus_project_id)), primus_wip_provider_name, primus_service_account_email)
        secundus_customer_data = read_in_bq(secundus_project_id, query_info.format(keyset=read_keyset(secundus_project_id)), secundus_wip_provider_name, secundus_service_account_email)

        # Create a set of names from the Primus and Secundus data
        primus_names = {row["name"] for row in primus_customer_data}
        secundus_names = {row["name"] for row in secundus_customer_data}

        # Find the common names in the Secundus data
        common = [name for name in secundus_names if name in primus_names]

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