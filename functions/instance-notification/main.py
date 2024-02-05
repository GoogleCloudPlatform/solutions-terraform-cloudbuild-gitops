import os
import json
import base64
import requests
from time import sleep
from google.cloud import asset_v1
from google.cloud import resourcemanager_v3
from google.api_core.client_options import ClientOptions

def instance_notification(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    message_json = json.loads(pubsub_message)

    test_project        = os.environ.get('TEST_PROJECT', 'Specified environment variable is not set.')
    secure_tag_key      = os.environ.get('SECURE_TAG_KEY', 'Specified environment variable is not set.')
    secure_tag_value    = os.environ.get('SECURE_TAG_VALUE', 'Specified environment variable is not set.')
    
    sleep(30)

    try:
        search_asset_client     = asset_v1.AssetServiceClient()
        search_asset_request    = asset_v1.SearchAllResourcesRequest(
            scope       = f"projects/{test_project}",
            query       = f"NOT tagKeys:{secure_tag_key}",
            asset_types =["compute.googleapis.com/Instance"],
            read_mask   ="name"
        )
        search_asset_result = search_asset_client.search_all_resources(request = search_asset_request)
        for search_asset in search_asset_result:
            print(search_asset)
            if message_json['asset']['name'] in str(search_asset):
                print("Found non-compliant instance. Applying tag binding...")
                
                # set the regional endpoint
                regional_endpoint = f"{message_json['asset']['resource']['location']}-cloudresourcemanager.googleapis.com"
                client_options = ClientOptions(api_endpoint=regional_endpoint)

                # apply the tag binding
                tag_binding_client  = resourcemanager_v3.TagBindingsClient(client_options=client_options)
                tag_binding_request = resourcemanager_v3.CreateTagBindingRequest()
                tag_binding_request.tag_binding.parent = message_json['asset']['name']
                tag_binding_request.tag_binding.tag_value = secure_tag_value
                tag_binding_operation = tag_binding_client.create_tag_binding(request=tag_binding_request)

                print("Waiting for tag binding operation to complete...")
                tag_binding_response = tag_binding_operation.result()
                print(tag_binding_response)
                
                send_slack_chat_notification(message_json['asset']['name'], tag_binding_response)

    except Exception as error:
        print(f"Error in listing non-compliant instances: {error}")

def send_slack_chat_notification(assetName, tag_binding_response):
    try:
        slack_message = [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": f"Untagged Compute Instance Alert!"
                    }
                },
                {
                    "type": "section",
                    "fields": [
                        {
                            "type": "mrkdwn",
                            "text": f"*Project:* {assetName}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": f"*Instance:* {assetName}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": f"*Tag Binding Response:* {tag_binding_response}"
                        }
                    ]
                }
            ]
    
        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        slack_channel = os.environ.get('SLACK_CHANNEL', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": slack_channel,
            "text": "Untagged Compute Instance Alert!",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)