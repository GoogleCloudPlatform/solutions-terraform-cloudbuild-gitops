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
    print("""This Function was triggered by messageId {} published at {} to {}
    """.format(context.event_id, context.timestamp, context.resource["name"]))

    if 'attributes' in event:
        try:
            print(f"Raw event data: {event}")
            pubsub_message = event['attributes'])
            print(f"Pubsub message: {pubsub_message}")
            message_json = json.loads(pubsub_message)
    
            send_slack_chat_notification(message_json)
        except Exception as e:
            print(e)
    else:
        print("Missing data payload in function trigger event")

def send_slack_chat_notification(operations_json):
    slack_message = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"Cloud Deploy Operation Alert!"
                }
            },
            {
                "type": "divider"
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*Action:*\n{operations_json['Action']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*PipelineID:*\n{operations_json['DeliveryPipelineId']}"
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
            "text": f"{operations_json['Action']} in {operations_json['DeliveryPipelineId']} reported!",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)
