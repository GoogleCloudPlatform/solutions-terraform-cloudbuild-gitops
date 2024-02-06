import os
import json
import base64
import requests
from time import sleep
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
    secure_tag_value    = os.environ.get('SECURE_TAG_VALUE', 'Specified environment variable is not set.')
    
    # wait for 30 secs for instance operation to complete
    sleep(30)

    try:
        found_tag = False
        print(f"Evaluating instance: {message_json['asset']['name']}")

        # set the regional endpoint
        regional_endpoint = f"{message_json['asset']['resource']['location']}-cloudresourcemanager.googleapis.com"
        client_options = ClientOptions(api_endpoint=regional_endpoint)

        tag_binding_client  = resourcemanager_v3.TagBindingsClient(client_options=client_options)
        list_tag_binding_request = resourcemanager_v3.ListTagBindingsRequest(
            parent  = f"//compute.googleapis.com/projects/{test_project}/zones/{message_json['asset']['resource']['location']}/instances/{message_json['asset']['resource']['data']['id']}"
        )
        list_tag_binding_result  = tag_binding_client.list_tag_bindings(request = list_tag_binding_request)        
        
        # iterate through tag bindings to look for a match
        for tag_bindings in list_tag_binding_result:
            print(f"Found tag value on instance: {tag_bindings.tag_value}")
            if tag_bindings.tag_value == secure_tag_value:
                found_tag = True

        if not found_tag:
            print("Found non-compliant instance. Applying tag binding...")
            create_tag_binding_request = resourcemanager_v3.CreateTagBindingRequest()
            create_tag_binding_request.tag_binding.parent = f"//compute.googleapis.com/projects/{test_project}/zones/{message_json['asset']['resource']['location']}/instances/{message_json['asset']['resource']['data']['id']}"
            create_tag_binding_request.tag_binding.tag_value = secure_tag_value
            tag_binding_operation = tag_binding_client.create_tag_binding(request=create_tag_binding_request)

            print("Waiting for tag binding operation to complete...")
            create_tag_binding_response = tag_binding_operation.result()
            send_slack_chat_notification(test_project, message_json, create_tag_binding_response.tag_value_namespaced_name)

    except Exception as error:
        print(f"Error in listing tag bindings: {error}")

def send_slack_chat_notification(test_project, assetName, tag_value_namespaced_name):
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
                            "text": f"*Project:* {test_project}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": f"*Instance:* {assetName['asset']['resource']['data']['name']}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": f"*Network:* {assetName['asset']['resource']['data']['networkInterfaces'][0]['network']}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": f"*Subnetwork:* {assetName['asset']['resource']['data']['networkInterfaces'][0]['subnetwork']}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": f"*Tag Binding Response:* {tag_value_namespaced_name}"
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