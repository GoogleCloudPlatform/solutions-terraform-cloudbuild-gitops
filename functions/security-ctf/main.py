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
    slack_admin = os.environ.get('SLACK_ADMIN', 'Specified environment variable is not set.')

    if verify_request(timestamp,payload,slack_signature,slack_signing_secret):
        if payload.startswith("token="):
            # parse the slash command for access request
            url = urllib.parse.unquote(payload.split("response_url=")[1].split("&")[0])
            channel_id = payload.split("channel_id=")[1].split("&")[0]
            channel_name = payload.split("channel_name=")[1].split("&")[0]
            requestor_name = payload.split("user_name=")[1].split("&")[0]
            requestor_id = payload.split("user_id=")[1].split("&")[0]
            request_text = urllib.parse.unquote(payload.split("text=")[1].split("&")[0])
            print(f"New CTF Request: {channel_name}, {requestor_name}, {request_text}")
            
            input_text = request_text.split("+")
            if input_text[0].lower() == 'admin':
                if requestor_id == slack_admin:
                    slack_ack(url, "Hey, _CTF commando_, access is being provisioned!")
                    print(f"Provisioning access to env: {input_text[1]} for: {input_text[2]} as requested by: {requestor_name}")
                    http_endpoint = f"https://{deployment_region}-{deployment_project}.cloudfunctions.net/security-ctf-admin"
                    access_payload = {
                        "env_name": input_text[1],
                        "user_email": input_text[2],
                        "action": "grant"
                    }
                    function_response = call_function(http_endpoint, access_payload)
                    function_response_json = function_response.json()
                    
                    # compose message to respond back to the caller
                    slack_message = {
                        "attachments": [
                            {
                                "mrkdwn_in": ["text"],
                                "color": "#36a64f",
                                "title": "Request Details",
                                "fields": [
                                    {
                                        "title": "User Email",
                                        "value": input_text[2],
                                        "short": True
                                    },
                                    {
                                        "title": "Env Name",
                                        "value": input_text[1],
                                        "short": True
                                    }
                                ],
                                "footer": function_response_json['info']
                            }
                        ]
                    }

                    if function_response_json['result'] == "Success":
                        revoke_attachment = {
                            "text": "Use the button below to revoke this access.",
                            "fallback": "You are unable to play the game",
                            "callback_id": "wopr_game",
                            "color": "#3AA3E3",
                            "attachment_type": "default",
                            "actions": [
                                {
                                    "name": "revoke",
                                    "type": "button",
                                    "text": "Revoke Access",
                                    "value": f"type=admin+env_name={input_text[1]}+user_email={input_text[2]}+action=revoke",
                                    "style": "danger",
                                    "confirm": {
                                        "title": "Are you sure?",
                                        "text": f"Do you want to revoke access for *{input_text[2]}*?",
                                        "ok_text": "Do it!",
                                        "dismiss_text": "Stop, I've changed my mind!"
                                    }
                                }
                            ]
                        }
                        slack_message['attachments'].append(revoke_attachment)

                    return post_slack_response(url, slack_message)
                else:
                    print(f"{requestor_name} is unauthorized to execute CTF admin functions")
                    return {
                        "response_type": "ephemeral",
                        "type": "mrkdwn",
                        "text": f"You are unauthorized to execute CTF admin functions. Please ping <@{slack_admin}>"
                    }
            else:
                print("Invalid action invoked")
                return {
                    "response_type": "ephemeral",
                    "type": "mrkdwn",
                    "text": "Invalid slash command. Please use /ctf `user` and so on..."
                }
        elif payload.startswith("payload="):
            # handling the response action
            response_json = json.loads(urllib.parse.unquote(payload.split("payload=")[1]))
            value = response_json['actions'][0]['value']
            print(value)
            action_type = value.split("type=")[1].split("+")[0]
            env_name = value.split("env_name=")[1].split("+")[0]
            user_email = value.split("user_email=")[1].split("+")[0]
            action = value.split("action=")[1].split("+")[0]

            if action_type == "admin" and action == "revoke":
                slack_ack(response_json['response_url'], "Hey, _CTF commando_, access is being revoked!")
                print(f"Revoking access to env: {env_name} for: {user_email} as requested by: {response_json['user']['name']}")
                http_endpoint = f"https://{deployment_region}-{deployment_project}.cloudfunctions.net/security-ctf-admin"
                access_payload = {
                    "env_name": env_name,
                    "user_email": user_email,
                    "action": action
                }
                function_response = call_function(http_endpoint, access_payload)
                function_response_json = function_response.json()
    
                # compose message to respond back to the caller
                slack_message = {
                    "attachments": [
                        {
                            "mrkdwn_in": ["text"],
                            "color": "#36a64f",
                            "pretext": "Access Revoked!",
                            "title": "Request Details",
                            "fields": [
                                {
                                    "title": "User Email",
                                    "value": user_email,
                                    "short": True
                                },
                                {
                                    "title": "Env Name",
                                    "value": env_name,
                                    "short": True
                                }
                            ],
                            "footer": function_response_json['info']
                        }
                    ]
                }
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
