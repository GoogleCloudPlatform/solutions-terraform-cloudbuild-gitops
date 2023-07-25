import os
import base64
import json
import requests
from pytz import timezone
from datetime import datetime

def scc_slack_notification(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    message_json = json.loads(pubsub_message)
    if 'finding' in message_json and 'resource' in message_json:
        send_slack_chat_notification(message_json.get('finding'), message_json.get('resource'))
    else:
        print(message_json)
        send_slack_chat_notification(message_json.get('finding'), json.loads('{}'))

def send_slack_chat_notification(finding_json, resource_json):
    event_timestamp = datetime.fromisoformat(finding_json['eventTime'][0:19]).astimezone(timezone('Asia/Kolkata')).strftime('%Y-%m-%d %H:%M:%S')
    
    if 'description' in finding_json:
        description = finding_json.get('description', 'Unspecified')
    else:
        description = f"Source: {finding_json.get('parentDisplayName', 'Unspecified')}"
    

    slack_message = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"{finding_json.get('severity', 'Unspecified')} severity finding {finding_json.get('category', 'Unspecified')} detected!"
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
                        "text": f"*Project:*\n{resource_json.get('projectDisplayName', 'Unspecified')}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*When:*\n{event_timestamp} IST"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Resource Type:*\n{resource_json.get('type', 'Unspecified')}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Resource Name:*\n{resource_json.get('displayName', 'Unspecified')}"
                    }
                ]
            },
            {
                "type": "actions",
                "elements": []
            }
        ]
    
    if finding_json['findingClass'] == "MISCONFIGURATION":
        slack_message[4]['elements'].append({
                        "type": "button",
                        "text": {
                            "type": "plain_text",
                            "emoji": True,
                            "text": "Remediate"
                        },
                        "style": "primary",
                        "value": f"project_name={resource_json.get('projectDisplayName', 'Unspecified')}+resource_name={resource_json.get('displayName', 'Unspecified')}+resource_type={resource_json.get('type', 'Unspecified')}+resource_id={finding_json.get('resourceName', 'Unspecified')}+decision=Remediate",
                        "confirm": {
                            "title": {
                                "type": "plain_text",
                                "text": "Are you sure?"
                            },
                            "text": {
                                "type": "mrkdwn",
                                "text": f"Do you want to fix the finding *{finding_json.get('category', 'Unspecified')}*?"
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
                    })
    else:
        slack_message[4]['elements'].append({
                        "type": "button",
                        "text": {
                            "type": "plain_text",
                            "emoji": True,
                            "text": "Deactivate"
                        },
                        "style": "primary",
                        "value": f"project_name={resource_json.get('projectDisplayName', 'Unspecified')}+resource_name={resource_json.get('displayName', 'Unspecified')}+resource_type={resource_json.get('type', 'Unspecified')}+finding_path={finding_json.get('name', 'Unspecified')}+decision=Deactivate",
                        "confirm": {
                            "title": {
                                "type": "plain_text",
                                "text": "Are you sure?"
                            },
                            "text": {
                                "type": "mrkdwn",
                                "text": f"Do you want to deactivate the finding *{finding_json.get('category', 'Unspecified')}*?"
                            },
                            "confirm": {
                                "type": "plain_text",
                                "text": "Deactivate it"
                            },
                            "deny": {
                                "type": "plain_text",
                                "text": "Stop, I've changed my mind!"
                            }
                        }
                    })

    slack_message[4]['elements'].append({
                        "type": "button",
                        "text": {
                            "type": "plain_text",
                            "emoji": True,
                            "text": "Mute Finding"
                        },
                        "style": "danger",
                        "value": f"project_name={resource_json.get('projectDisplayName', 'Unspecified')}+resource_name={resource_json.get('displayName', 'Unspecified')}+resource_type={resource_json.get('type', 'Unspecified')}+finding_path={finding_json.get('name', 'Unspecified')}+decision=Mute",
                        "confirm": {
                            "title": {
                                "type": "plain_text",
                                "text": "Are you sure?"
                            },
                            "text": {
                                "type": "mrkdwn",
                                "text": f"Do you want to mute the finding *{finding_json.get('category', 'Unspecified')}*?"
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
                    })

    try:
        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        slack_channel = os.environ.get('SLACK_CHANNEL', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": slack_channel,
            "text": f"{finding_json.get('severity', 'Unspecified')} severity finding {finding_json.get('category', 'Unspecified')} detected!",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)