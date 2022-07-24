import os
import json
import requests

def admin_access(request):
    if request.get_json():
        request_json = request.get_json()
        input_text = request_json['value'].split("+",2)
        print(input_text)
        if(len(input_text)<3):
            print("One or more request elements missing. Please include project `project_id` duration `hours.mins` and `reason for access`")
            return 'Invalid request'
        else:
            project_id = input_text[0].lower()
            duration = input_text[1]
            reason = input_text[2]
            try:
                if '.' in duration:
                    duration_hours = float(duration.split(".",1)[0])
                    duration_mins = float(duration.split(".",1)[1])
                else:
                    duration_hours = float(duration)
                    duration_mins = 0
                if duration_hours < 0 or duration_mins < 0 or duration_hours > 4 or duration_mins > 59:
                    raise Exception("Invalid user input. Hours and mins are outside of allowed ranges.")
            except Exception as e:
                print("Error: ", e)
                print("The duration doesn't conform to the hours `0-4` dot `.` mins `0-59` pattern.")
                return 'Invalid request'

            send_slack_chat_notification("Slack User", "slack@agarsand.altostrat.com", project_id, duration_hours, duration_mins, reason)
            return 'Request Succeeded!'
    else:
        return 'Invalid request'

def send_slack_chat_notification(requestor_name, requestor_email, project_id, duration_hours, duration_mins, reason):
    slack_message = [ 
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"New Access Request from {requestor_name}!"
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
                        "text": f"*Project:*\n{project_id}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Reason:*\n{reason}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Hours:*\n{duration_hours}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Mins:*\n{duration_mins}"
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
                            "text": "Approve"
                        },
                        "style": "primary",
                        "value": f"requestor_email={requestor_email}+project_id={project_id}+duration_hours={duration_hours}+duration_mins={duration_mins}+decision=Approved",
                        "confirm": {
                            "title": {
                                "type": "plain_text",
                                "text": "Are you sure?"
                            },
                            "text": {
                                "type": "mrkdwn",
                                "text": f"Do you want to approve admin access from {requestor_name}?"
                            },
                            "confirm": {
                                "type": "plain_text",
                                "text": "Yes, approved!"
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
                        "value": f"requestor_email={requestor_email}+project_id={project_id}+duration_hours={duration_hours}+duration_mins={duration_mins}+decision=Rejected",
                        "confirm": {
                            "title": {
                                "type": "plain_text",
                                "text": "Are you sure?"
                            },
                            "text": {
                                "type": "mrkdwn",
                                "text": f"Do you want to reject admin access from {requestor_name}?"
                            },
                            "confirm": {
                                "type": "plain_text",
                                "text": "Yes, rejected!"
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
        slack_channel = "C03RFE89508"
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": slack_channel,
            "text": f"New Admin Access Request from {requestor_email}!",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)
