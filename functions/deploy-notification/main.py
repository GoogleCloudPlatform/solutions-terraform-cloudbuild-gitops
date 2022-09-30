import os
import base64
import json
import requests

def deploy_notification(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    message_json = json.loads(pubsub_message)
    
    send_slack_chat_notification(message_json['finding'], message_json['resource'])

def send_slack_chat_notification(finding_json, resource_json):
    slack_message = [ 
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"{finding_json['severity']} severity finding {finding_json['category']} detected!"
                }
            },
            {
                "type": "divider"
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"{finding_json['description']}\n"
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*Project:*\n{resource_json['projectDisplayName']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*When:*\n{finding_json['eventTime']} UTC"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Resource Type:*\n{resource_json['type']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Resource Name:*\n{resource_json['displayName']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Resource URI:*\n{finding_json['externalUri']}"
                    }
                ]
            }
        ]
    try:
        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        slack_channel = os.environ.get('SLACK_SECOPS_CHANNEL', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": slack_channel,
            "text": f"{finding_json['severity']} severity finding {finding_json['category']} detected!",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)
