import os
import time
import json
import hmac
import hashlib
import urllib.parse
import requests
import google.auth.transport.requests
import google.oauth2.id_token
from requests.structures import CaseInsensitiveDict

def admin_access(request):
    # extracting payload information from POST
    timestamp = request.headers['X-Slack-Request-Timestamp']
    payload = request.get_data().decode('utf-8')
    slack_signature = request.headers['X-Slack-Signature']
    slack_signing_secret = os.environ.get('SLACK_SIGNING_SECRET', 'Specified environment variable is not set.')

    if verify_request(timestamp,payload,slack_signature,slack_signing_secret):
        if payload.startswith("token="):
            # handling the request action
            url = urllib.parse.unquote(payload.split("response_url=")[1].split("&")[0])
            requestor_name = payload.split("user_name=")[1].split("&")[0],
            requestor_id = payload.split("user_id=")[1].split("&")[0],
            request_text = payload.split("text=")[1].split("&")[0],
            print(requestor_name, requestor_id, request_text)
            input_text = request_text.split("+",2)
            if(len(input_text)<3):
                print('Invalid request')
                ack_text = "One or more request elements missing. Please include project `project_id` duration `hours.mins` and `reason for access`"
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
                    print("Invalid request")
                    print("Error: ", e)
                    ack_text = "The duration doesn't conform to the hours `0-4` dot `.` mins `0-59` pattern."
                send_slack_chat_notification(requestor_name, requestor_id, project_id, duration_hours, duration_mins, reason)
                print("Request Succeeded!")
                ack_text = "Hey, _slash commando_, we got your request!"
        else:
            print("Not a valid payload!")
            ack_text = "Hey, _slash commando_, that was not a valid payload!"
        
        slack_ack(url, ack_text)
        return {
                'statusCode': 200
            }
    else:
        return {
            'statusCode': 401,
            'body': json.dumps("Unauthorized!")
        }

def verify_request(timestamp,payload,slack_signature,slack_signing_secret):
    # Check that the request is no more than 60 seconds old
    if (int(time.time()) - int(timestamp)) > 60:
        print("Verification failed. Request is out of date.")
        return False
    else:
        sig_basestring = ('v0:' + timestamp + ':' + payload)
        my_signature = 'v0=' + hmac.new(slack_signing_secret.encode('utf-8'), sig_basestring.encode('utf-8'), hashlib.sha256).hexdigest()
        if my_signature == slack_signature:
            print("Verification succeeded. Signature valid.")
            return True
        else:
            print("Verification failed. Signature invalid.")
            return False

def call_function(http_endpoint, response_payload):
    auth_req = google.auth.transport.requests.Request()
    id_token = google.oauth2.id_token.fetch_id_token(auth_req, http_endpoint)
    
    headers = CaseInsensitiveDict()
    headers["Accept"] = "application/json"
    headers["Authorization"] = f"Bearer {id_token}"
    headers["Content-Type"] = "application/json"

    response = requests.post(http_endpoint, json=response_payload, headers=headers)
    return response.status_code

def slack_ack(url, ack_text):
    ack_message = {
        "response_type": "ephemeral",
        "type": "mrkdwn",
        "text": ack_text
    }
    response = requests.post(url, data=json.dumps(ack_message), headers={'Content-Type': 'application/json'})
    print(f"Slack responded with Status Code: {response.status_code}")

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
