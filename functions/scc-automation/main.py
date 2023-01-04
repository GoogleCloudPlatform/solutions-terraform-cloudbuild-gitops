import os
import base64
import json
import requests
from pytz import timezone
from datetime import datetime

def scc_automation(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    message_json = json.loads(pubsub_message)
    send_slack_chat_notification(message_json['finding'], message_json['resource'])

def send_slack_chat_notification(finding_json, resource_json):
    event_timestamp = datetime.fromisoformat(finding_json['eventTime'][:-1]).astimezone(timezone('Asia/Kolkata')).strftime('%Y-%m-%d %H:%M:%S')
    
    if 'severity' in finding_json: 
        severity = finding_json['severity']
    else:
        severity = "Unspecified"
    if 'description' in finding_json:
        description = finding_json['description']
    else:
        description = f"Source: {finding_json['parentDisplayName']}"
    
    slack_message = [ 
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"{severity} severity finding {finding_json['category']} detected!"
                }
            },
            {
                "type": "divider"
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"{description}\n"
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
                        "text": f"*When:*\n{event_timestamp} IST"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Resource Type:*\n{resource_json['type']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Resource Name:*\n{resource_json['displayName']}"
                    }
                ]
            },
            {
                "type": "actions",
                "elements": [
                    {
                        "type": "button",
                        "text": {
                            "type": "plain_text",
                            "emoji": True,
                            "text": "Remediate"
                        },
                        "style": "primary",
                        "value": f"project_name={resource_json['projectDisplayName']}+resource_name={resource_json['displayName']}+resource_type={resource_json['type']}+resource_id={resource_json['name']}+decision=Remediate",
                        "confirm": {
                            "title": {
                                "type": "plain_text",
                                "text": "Are you sure?"
                            },
                            "text": {
                                "type": "mrkdwn",
                                "text": f"Do you want to fix the finding *{finding_json['category']}*?"
                            },
                            "confirm": {
                                "type": "plain_text",
                                "text": "Fix it"
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
                            "text": "Mute Finding"
                        },
                        "style": "danger",
                        "value": f"project_name={resource_json['projectDisplayName']}+resource_name={resource_json['displayName']}+resource_type={resource_json['type']}+finding_path={finding_json['name']}+decision=Mute",
                        "confirm": {
                            "title": {
                                "type": "plain_text",
                                "text": "Are you sure?"
                            },
                            "text": {
                                "type": "mrkdwn",
                                "text": f"Do you want to mute the finding *{finding_json['category']}*?"
                            },
                            "confirm": {
                                "type": "plain_text",
                                "text": "Mute it"
                            },
                            "deny": {
                                "type": "plain_text",
                                "text": "Stop, I've changed my mind!"
                            }
                        }
                    }
                ]
            }
        ]
    try:
        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        slack_channel = os.environ.get('SLACK_CHANNEL', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": slack_channel,
            "text": f"{severity} severity finding {finding_json['category']} detected!",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)