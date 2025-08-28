import os
import json
import base64
import random
import string
from google.cloud import storage, kms

def serverless_security(request):
     
     event = json.loads(request.get_data().decode('UTF-8'))
     print("Writing a token to the given bucket...")
     try:
          # Declare environment variables
          project_name   = os.environ.get('PROJECT_NAME')
          token_bucket   = os.environ.get('TOKEN_BUCKET')
          token_object   = os.environ.get('TOKEN_OBJECT')
          kms_key        = os.environ.get('KMS_KEY')
     
          # Create a Storage client
          storage_client = storage.Client(project=project_name)

          # Get the bucket and object handles
          bucket_handle = storage_client.bucket(token_bucket)
          object_handle = bucket_handle.blob(token_object)

          # Generate a random token
          length = 8
          secure_token = ''.join(random.choices(string.ascii_letters + string.digits, k=length))

          # Convert the secure_token plaintext to bytes.
          plaintext_bytes = secure_token.encode("utf-8")

          # Create a KMS client
          kms_client = kms.KeyManagementServiceClient()

          # Call the KMS API to encrypt the secure_token plaintext
          encrypt_response = kms_client.encrypt(
               request={
                    "name": kms_key,
                    "plaintext": plaintext_bytes,
               }
          )

          # Upload the secure token to the bucket
          object_handle.upload_from_string(base64.b64encode(encrypt_response.ciphertext))
          info = f"Successfully stored secure token to bucket: {secure_token}"
     except Exception as e:
          info = f"Could not write secure token to bucket: {e}"
     
     data = {
        "info": info
     }
     return json.dumps(data), 200, {'Content-Type': 'application/json'}
