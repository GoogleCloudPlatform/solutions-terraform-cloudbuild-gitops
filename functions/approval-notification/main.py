import os
import base64
import json
import requests

def approval_notification(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    if 'attributes' in event:
        try:
            pubsub_message = json.dumps(event['attributes'])
            message_json = json.loads(pubsub_message)
            send_slack_chat_notification(message_json)
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
                    "text": f"Deploy Approval Alert for {message_json['DeliveryPipelineId']}!"
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
                        "text": f"*Action:*\n{message_json['Action']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*TargetId:*\n{message_json['TargetId']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*ReleaseId:*\n{message_json['ReleaseId']}"
                    }
                ]
            }
        ]
    if message_json['Action'] == "Required":
        slack_message.append({
            "type": "actions",
            "elements": [
                {
                    "type": "button",
                    "text": {
                        "type": "plain_text",
                        "emoji": True,
                        "text": "Approve"
                    },
                    "style": "primary",
                    "value": f"rollout-name={message_json['RolloutId']}+pipeline-name={message_json['DeliveryPipelineId']}+region={message_json['Location']}+release-name={message_json['ReleaseId']}+decision=Approved",
                    "confirm": {
                        "title": {
                            "type": "plain_text",
                            "text": "Are you sure?"
                        },
                        "text": {
                            "type": "mrkdwn",
                            "text": f"Do you want to *approve* the rollout?"
                        },
                        "confirm": {
                            "type": "plain_text",
                            "text": "Approve it!"
                        },
                        "deny": {
                            "type": "plain_text",
                            "text": "Stop, I've changed my mind!"
                        }
                    }
                },
                {
                    "type": "button",
                    "text": {
                        "type": "plain_text",
                        "emoji": True,
                        "text": "Reject"
                    },
                    "style": "danger",
                    "value": f"rollout-name={message_json['RolloutId']}+pipeline-name={message_json['DeliveryPipelineId']}+region={message_json['Location']}+release-name={message_json['ReleaseId']}+decision=Rejected",
                    "confirm": {
                        "title": {
                            "type": "plain_text",
                            "text": "Are you sure?"
                        },
                        "text": {
                            "type": "mrkdwn",
                            "text": f"Do you want to *reject* the rollout?"
                        },
                        "confirm": {
                            "type": "plain_text",
                            "text": "Reject it!"
                        },
                        "deny": {
                            "type": "plain_text",
                            "text": "Stop, I've changed my mind!"
                        }
                    }
                }
            ]
        })
    try:
        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        slack_channel = os.environ.get('SLACK_DEVOPS_CHANNEL', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": slack_channel,
            "text": f"Approval for {message_json['ReleaseId']} to {message_json['TargetId']} {message_json['Action']}!",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)
