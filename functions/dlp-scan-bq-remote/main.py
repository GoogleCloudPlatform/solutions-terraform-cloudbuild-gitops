import os
import functions_framework
from flask import jsonify
from google.cloud import dlp

@functions_framework.http
def dlp_scan_bq_remote(request):
  # create a dlp client for this project
  dlp_client = dlp.DlpServiceClient()

  # read os environment variables
  KMS_KEY       = os.environ.get('KMS_KEY')
  WRAPPED_KEY   = os.environ.get('WRAPPED_KEY')
  PROJECT_NAME  = os.environ.get('PROJECT_NAME')
  parent        = f"projects/{PROJECT_NAME}"
  
  # The infoTypes of information to match
  INFO_TYPES = ['PHONE_NUMBER', 'EMAIL_ADDRESS', 'US_SOCIAL_SECURITY_NUMBER']
  inspect_config = {"info_types": [{"name": info_type} for info_type in INFO_TYPES]}
  deidentify_config = {
    "info_type_transformations": {
      "transformations": [
        {
          "info_types": [{"name": info_type} for info_type in INFO_TYPES],
          "primitive_transformation": {
            "cryptoDeterministicConfig": {
              "cryptoKey": {
                "kmsWrapped": {
                  "cryptoKeyName": KMS_KEY,
                  "wrappedKey": WRAPPED_KEY
                }
              },
              "surrogateInfoType": {
                "name": "TOKENIZED_VALUE"
              }
            }
          }
        }
      ]
    }
  }  
  try:
    return_value = []
    request_json = request.get_json()
    calls = request_json['calls']
    for call in calls:
      response_text = dlp_client.deidentify_content(
        request={
            "parent": parent,
            "deidentify_config": deidentify_config,
            "inspect_config": inspect_config,
            "item": {"value": call[0]},
        }
      )
      return_value.append(response_text.item.value)
    return jsonify( { "replies":  return_value } )
  except Exception as e:
    return jsonify( { "errorMessage": str(e) } ), 400