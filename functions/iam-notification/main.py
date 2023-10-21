import os
import json
import base64
import requests

def iam_notification(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    message_json = json.loads(pubsub_message)
    delta = []
    
    for new_binding in message_json["asset"]["iamPolicy"]["bindings"]:
        if new_binding not in message_json["priorAsset"]["iamPolicy"]["bindings"]:
            old_binding = next((b for b in message_json["priorAsset"]["iamPolicy"]["bindings"] if b["role"] == new_binding["role"]), "no_old_binding")
            print(f"Found New Binding: {new_binding} with Old Binding: {old_binding}")
            if old_binding == "no_old_binding": 
                # no old binding hence report new binding as is
                delta.append(new_binding)
            else: 
                # compare against old binding and find new members
                new_member = next(m for m in new_binding["members"] if m not in old_binding["members"])
                delta.append({
                    "members": [new_member],
                    "role": new_binding["role"]
                })
    
    print(f"Delta: {delta}")
    assetType = message_json["asset"]["assetType"].split("/")[-1]
    assetName = message_json["asset"]["name"].split("/")[-1]
    send_slack_chat_notification(assetType, assetName, delta)
        
def send_slack_chat_notification(assetType, assetName, delta):
    try:
        slack_message = [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": f"IAM Policy Grant Alert!"
                    }
                },
                {
                    "type": "section",
                    "fields": [
                        {
                            "type": "mrkdwn",
                            "text": f"*{assetType}:*\n{assetName}"
                        }
                    ]
                }
            ]

        for binding in delta:
            slack_message.append(
                {
                    "type": "divider"
                }
            )
            slack_message[3]["fields"].append(
                {
                    "type": "section",
                    "fields": [
                        {
                            "type": "mrkdwn",
                            "text": f"*Members:*\n{binding['members']}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": f"*Role:*\n{binding['role']}"
                        }
                    ]
                }
            )
    
        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        slack_channel = os.environ.get('SLACK_CHANNEL', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": slack_channel,
            "text": "IAM Policy Grant Alert!",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)