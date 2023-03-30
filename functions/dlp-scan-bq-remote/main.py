import os
import functions_framework
from flask import jsonify
from google.cloud import dlp

@functions_framework.http
def dlp_scan_bq_remote(request):
  # The infoTypes of information to match
  INFO_TYPES = [
    'PHONE_NUMBER', 'EMAIL_ADDRESS', 'US_SOCIAL_SECURITY_NUMBER'
  ]
  dlp_client = dlp.DlpServiceClient()
  PROJECT_NAME = os.environ.get('PROJECT_NAME')
  parent = f"projects/{PROJECT_NAME}"
  inspect_config = {"info_types": [{"name": info_type} for info_type in INFO_TYPES]}
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
  try:
    return_value = []
    request_json = request.get_json()
    calls = request_json['calls']
    for call in calls:
      return_value.append(response_text = dlp_client.deidentify_content(
        request={
            "parent": parent,
            "deidentify_config": deidentify_config,
            "inspect_config": inspect_config,
            "item": {"value": call},
        }
    ))
    print(return_value)
    return jsonify( { "replies":  return_value } )
  except Exception as e:
    return jsonify( { "errorMessage": str(e) } ), 400