import os
import base64
import json
import requests

def identity_notification(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    # print("""This Function was triggered by messageId {} published at {} to {}
    # """.format(context.event_id, context.timestamp, context.resource["name"]))

    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    message_json = json.loads(pubsub_message)

    print(message_json)

    if 'severity' in message_json:
        try:
            if message_json['severity'] == "NOTICE":
                send_slack_chat_notification(message_json['protoPayload'])
            else:
                print("Ignoring message")
        except Exception as e:
            print(e)
    else:
        print("Missing data payload in function trigger event")

def send_slack_chat_notification(message_json):
    slack_message = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"Cloud Identity Activity Alert!"
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
                        "text": f"*User:*\n{message_json['authenticationInfo']['principalEmail']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Event:*\n{message_json['metadata']['event'][0]['eventName']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Timestamp:*\n{message_json['metadata']['activityId']['timeUsec']}"
                    }
                ]
            }
        ]
    try:
        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        slack_channel = os.environ.get('SLACK_DEVOPS_CHANNEL', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": slack_channel,
            "text": f"{message_json['authenticationInfo']['principalEmail']} performed {message_json['metadata']['event'][0]['eventName']}!",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)