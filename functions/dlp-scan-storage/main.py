import os
from google.cloud import dlp
from google.cloud import storage

# declare environment variables
REDACTED_BUCKET_NAME = os.environ.get('REDACTED_BUCKET_NAME')
PROJECT_NAME = os.environ.get('PROJECT_NAME')
storage_client = storage.Client(project=PROJECT_NAME)

# The minimum_likelihood (Enum) required before returning a match
MIN_LIKELIHOOD = 'POSSIBLE'

# The maximum number of findings to report (0 = server maximum)
MAX_FINDINGS = 0

# The infoTypes of information to match
INFO_TYPES = [
    'PHONE_NUMBER', 'EMAIL_ADDRESS', 'US_SOCIAL_SECURITY_NUMBER', 'INDIA_AADHAAR_INDIVIDUAL'
]

def dlp_scan_storage(event, context):
    """Triggered by a change to a Cloud Storage bucket.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    print(f"Processing file: {event['name']}.")

    try:
        mybucket = storage_client.get_bucket(event['bucket'])
        blob = mybucket.get_blob(event['name'])
        print("Input file fetch successful!")
        
        dlp_client = dlp.DlpServiceClient()
        parent = f"projects/{PROJECT_NAME}"
        inspect_config = {"info_types": [{"name": info_type} for info_type in INFO_TYPES]}
        
        if event['contentType']=='text/plain':
            file_contents = blob.download_as_text()
            item = {"value": file_contents}
            deidentify_config = {
                "info_type_transformations": {
                    "transformations": [
                        {
                            "primitive_transformation": {
                                "character_mask_config": {
                                    "masking_character": '#',
                                    "number_to_mask": 0,
                                }
                            }
                        }
                    ]
                }
            }
            response_text = dlp_client.deidentify_content(
                request={
                    "parent": parent,
                    "deidentify_config": deidentify_config,
                    "inspect_config": inspect_config,
                    "item": item,
                }
            )
            destination_blob_name = event['name'].split(".")[-2] + "_redacted." + event['name'].split(".")[-1]
            upload_redacted_blob(event['contentType'],response_text.item.value,destination_blob_name)
        
        elif event['contentType']=='image/png':
            image_redaction_configs = []
            for info_type in INFO_TYPES:
                image_redaction_configs.append({"info_type": {"name": info_type}})
            
            file_contents = blob.download_as_bytes()
            byte_item = {"type_": 3, "data": file_contents}
            
            response_image = dlp_client.redact_image(
                request={
                    "parent": parent,
                    "inspect_config": inspect_config,
                    "image_redaction_configs": image_redaction_configs,
                    "byte_item": byte_item,
                }
            )
            destination_blob_name = event['name'].split(".")[-2] + "_redacted." + event['name'].split(".")[-1]
            upload_redacted_blob(event['contentType'],response_image.redacted_image,destination_blob_name)
            
        else:
            print("Sorry, I don't recognize the file format!")
    
    except Exception as e:
        print(e)
        print("Input file read unsuccessful!")

def upload_redacted_blob(blob_type, blob_upload, destination_blob_name):
    """Uploads a file to the bucket."""
    try:
        bucket = storage_client.get_bucket(REDACTED_BUCKET_NAME)
        blob = bucket.blob(destination_blob_name)

        if blob_type=='text/plain':
            blob.upload_from_string(blob_upload)
        elif blob_type=='image/png':
            blob.upload_from_string(blob_upload)
        print(f"Redacted file {destination_blob_name} uploaded!")
        return True
    except Exception as e:
        print(e)
        print("Redacted file upload unsuccessful!")
        return False