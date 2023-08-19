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

def security_ctf(request):
    # extracting payload information from POST
    timestamp = request.headers['X-Slack-Request-Timestamp']
    payload = request.get_data().decode('utf-8')
    slack_signature = request.headers['X-Slack-Signature']
    slack_signing_secret = os.environ.get('SLACK_SIGNING_SECRET', 'Specified environment variable is not set.')
    slack_ctf_easy_channel = os.environ.get('SLACK_CTF_EASY_CHANNEL', 'Specified environment variable is not set.')
    slack_ctf_hard_channel = os.environ.get('SLACK_CTF_HARD_CHANNEL', 'Specified environment variable is not set.')
    deployment_project = os.environ.get('DEPLOYMENT_PROJECT', 'Specified environment variable is not set.')
    deployment_region = os.environ.get('DEPLOYMENT_REGION', 'Specified environment variable is not set.')

    if verify_request(timestamp,payload,slack_signature,slack_signing_secret):
        if payload.startswith("token="):
            # parse the slash command for access request
            url = urllib.parse.unquote(payload.split("response_url=")[1].split("&")[0])
            requestor_name = payload.split("user_name=")[1].split("&")[0]
            requestor_id = payload.split("user_id=")[1].split("&")[0]
            request_text = payload.split("text=")[1].split("&")[0]
            print(f"New Access Request: {requestor_name}, {requestor_id}, {request_text}")
            input_text = request_text.split("+",3)
            if(len(input_text)<4):
                print("Invalid user input - one or more request elements missing.")
                return {
                    "response_type": "ephemeral",
                    "type": "mrkdwn",
                    "text": "One or more request elements missing. Please include project `project_id` role `role_name` duration `hours.mins` and `reason for access`"
                }
            else:
                project_id = input_text[0].lower()
                role_name = input_text[1]
                duration = input_text[2]
                reason = input_text[3]
                
                if role_name in ['viewer', 'editor', 'owner']:
                    print(f"Invalid user input - Primitive/Basic roles are not permitted.")
                    return {
                        "response_type": "ephemeral",
                        "type": "mrkdwn",
                        "text": "Primitive/Basic roles are not permitted - please use a Predefined role such as `compute.admin`."
                    }
                
                try:
                    if '.' in duration:
                        duration_hours = float(duration.split(".",1)[0])
                        duration_mins = float(duration.split(".",1)[1])
                    else:
                        duration_hours = float(duration)
                        duration_mins = 0
                    if duration_hours < 0 or duration_mins < 0 or duration_hours > 4 or duration_mins > 59:
                        raise Exception("hours and mins are outside of allowed ranges.")
                except Exception as e:
                    print(f"Invalid user input - {e}")
                    return {
                        "response_type": "ephemeral",
                        "type": "mrkdwn",
                        "text": "The duration doesn't conform to the hours `0-4` dot `.` mins `0-59` pattern."
                    }
                
                # if everything looks good, compose the slack message to be sent for approval 
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
                                "text": f"*Role:*\n{role_name}"
                            },
                            {
                                "type": "mrkdwn",
                                "text": f"*Duration:*\n{duration_hours} hrs {duration_mins} mins"
                            },
                            {
                                "type": "mrkdwn",
                                "text": f"*Reason:*\n{reason}"
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
                                "value": f"requestor_name={requestor_name}+requestor_id={requestor_id}+project_id={project_id}+role_name={role_name}+duration_hours={duration_hours}+duration_mins={duration_mins}+decision=Approved",
                                "confirm": {
                                    "title": {
                                        "type": "plain_text",
                                        "text": "Are you sure?"
                                    },
                                    "text": {
                                        "type": "mrkdwn",
                                        "text": f"Do you want to approve access request from {requestor_name}?"
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
                                "value": f"requestor_name={requestor_name}+requestor_id={requestor_id}+project_id={project_id}+role_name={role_name}+duration_hours={duration_hours}+duration_mins={duration_mins}+decision=Rejected",
                                "confirm": {
                                    "title": {
                                        "type": "plain_text",
                                        "text": "Are you sure?"
                                    },
                                    "text": {
                                        "type": "mrkdwn",
                                        "text": f"Do you want to reject access request from {requestor_name}?"
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
                if post_slack_message(slack_approver_channel, f"New Access Request from {requestor_name}!", slack_message):
                    print("Access request sent to approvers!")
                    slack_text = "Access request sent to approvers!"
                else:
                    print("Access request to approvers failed!")
                    slack_text = "Access request to approvers failed!"

                # send a confirmation to requestor
                slack_message = {
                    "attachments": [
                        {
                            "mrkdwn_in": ["text"],
                            "color": "#36a64f",
                            "pretext": f"Hey {requestor_name}! Your access request has been processed!",
                            "title": "Request Details",
                            "fields": [
                                {
                                    "title": "Project",
                                    "value": project_id,
                                    "short": True
                                },
                                {
                                    "title": "Role",
                                    "value": role_name,
                                    "short": True
                                },
                                {
                                    "title": "Duration",
                                    "value": f"{duration_hours} hrs {duration_mins} mins",
                                    "short": True
                                },
                                {
                                    "title": "Reason",
                                    "value": reason,
                                    "short": True
                                }
                            ],
                            "footer": slack_text
                        }
                    ]
                }
                return post_slack_response(url, slack_message)
        elif payload.startswith("payload="):
            # handling the response action
            response_json = json.loads(urllib.parse.unquote(payload.split("payload=")[1]))
            value = response_json['actions'][0]['value']
            print(value)
            requestor_name = value.split("requestor_name=")[1].split("+")[0]
            requestor_id = value.split("requestor_id=")[1].split("+")[0]
            project_id = value.split("project_id=")[1].split("+")[0]
            role_name = value.split("role_name=")[1].split("+")[0]
            decision = value.split("decision=")[1].split("+")[0]
            
            # compose slack message used for response back to requestor
            slack_message = [
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "NEW_TEXT"
                    }
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
                            "text": f"*Role:*\n{role_name}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": f"*Actioned by:*\n{response_json['user']['name']}"
                        }
                    ]
                }
            ]

            if decision == "Approved":
                slack_ack(response_json['response_url'], "Hey, _secops commando_, access is being provisioned!")
                print(f"Provisioning access approved by Caller Name: {response_json['user']['name']}, Caller ID: {response_json['user']['id']}")
                http_endpoint = f"https://{deployment_region}-{deployment_project}.cloudfunctions.net/provision-access"
                response_payload = {
                    "caller_name": response_json['user']['name'],
                    "caller_id": response_json['user']['id'],
                    "value": value,
                    "response_url": response_json['response_url']
                }
                function_response = call_function(http_endpoint, response_payload)
                function_response_json = function_response.json()
                if function_response_json['result'] == "Success":
                    response_subject = "This access request was approved and executed!"
                else:
                    response_subject = "This access request was approved but execution failed!"
            
            elif decision == "Rejected":
                print(f"Access request rejected by Caller Name: {response_json['user']['name']}, Caller ID: {response_json['user']['id']}")
                response_subject = "This access request was rejected!"
            
            # post message back to the requestor
            slack_message[0]['text']['text'] = f"_Hey {requestor_name}!_ :wave: _{response_subject}_"
            if decision == "Approved":
                slack_message[1]['fields'].append({
                    "type": "mrkdwn",
                    "text": f"*Info:*\n{function_response_json['info']}"
                })
            if post_slack_message(requestor_id, response_subject, slack_message):
                response_footer = "The access requestor has been informed about this action."
            else:
                response_footer = "We couldn't inform the access requestor due to an error."
            print(response_footer)
            
            # compose message to respond back to the caller
            slack_message = {
                "attachments": [
                    {
                        "mrkdwn_in": ["text"],
                        "color": "#36a64f",
                        "pretext": response_subject,
                        "title": "Request Details",
                        "fields": [
                            {
                                "title": "Requestor",
                                "value": requestor_name,
                                "short": True
                            },
                            {
                                "title": "Project",
                                "value": project_id,
                                "short": True
                            },
                            {
                                "title": "Role",
                                "value": role_name,
                                "short": True
                            },
                            {
                                "title": "Actioned By",
                                "value": response_json['user']['name'],
                                "short": True
                            }
                        ],
                        "footer": response_footer
                    }
                ]
            }
            if decision == "Approved":
                slack_message['attachments'][0]['fields'].append({
                    "title": "Info",
                    "value": function_response_json['info'],
                    "short": True
                })
            return post_slack_response(response_json['response_url'], slack_message)
        else:
            print("Not a valid payload!")
            return {
                'statusCode': 200
            }
    else:
        print("Unauthorized request!")
        return {
            'statusCode': 401,
            'body': json.dumps("Unauthorized request!")
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

    return requests.post(http_endpoint, json=response_payload, headers=headers)

def slack_ack(url, ack_text):
    ack_message = {
        "response_type": "ephemeral",
        "type": "mrkdwn",
        "text": ack_text
    }
    response = requests.post(url, data=json.dumps(ack_message), headers={'Content-Type': 'application/json'})
    print(f"Slack responded with Status Code: {response.status_code}")

def post_slack_message(slack_channel, slack_text, slack_message):
    try:
        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": slack_channel,
            "text": slack_text,
            "blocks": json.dumps(slack_message)
        })
        print(f"Message posted - Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        raise(e)

def post_slack_response(url, slack_message):
    response = requests.post(url, data=json.dumps(slack_message), headers={'Content-Type': 'application/json'})
    print(f"Message posted - Slack responded with Status Code: {response.status_code}")
    return {
        'statusCode': response.status_code
    }
