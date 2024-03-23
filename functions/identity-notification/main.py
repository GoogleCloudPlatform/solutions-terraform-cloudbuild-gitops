import os
import base64
import json
import requests
from pytz import timezone
from datetime import datetime

def identity_notification(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    # print("""This Function was triggered by messageId {} published at {} to {}
    # """.format(context.event_id, context.timestamp, context.resource["name"]))

    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    event_json = json.loads(pubsub_message)

    if 'protoPayload' in event_json:
        send_slack_chat_notification(event_json['protoPayload'])
    else:
        print("Missing data payload in function trigger event")

def send_slack_chat_notification(message_json):
    try:
        posix_ts    = int(message_json['metadata']['activityId']['timeUsec'])/1000000
        timestamp   = datetime.utcfromtimestamp(posix_ts).astimezone(timezone('Asia/Kolkata')).strftime('%Y-%m-%d %H:%M:%S')

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
                            "text": f"*Timestamp:*\n{timestamp} IST"
                        }
                    ]
                }
            ]
    
        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        slack_channel = os.environ.get('SLACK_CHANNEL', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": slack_channel,
            "text": f"{message_json['authenticationInfo']['principalEmail']} performed {message_json['metadata']['event'][0]['eventName']} at {timestamp} IST!",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)