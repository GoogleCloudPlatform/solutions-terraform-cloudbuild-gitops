import os
import time
import json
import hmac
import hashlib
import urllib.parse
import requests
import google.auth.transport.requests
import google.oauth2.id_token
from google.cloud import functions_v1
from requests.structures import CaseInsensitiveDict

def scc_remediation(request):
    # extracting payload information from POST
    timestamp = request.headers['X-Slack-Request-Timestamp']
    payload = request.get_data().decode('utf-8')
    slack_signature = request.headers['X-Slack-Signature']
    slack_signing_secret = os.environ.get('SLACK_SIGNING_SECRET')

    if verify_request(timestamp,payload,slack_signature,slack_signing_secret):
        if payload.startswith("payload="):
            # handling the response action
            response_json = json.loads(urllib.parse.unquote(payload.split("payload=")[1]))
            url = response_json['response_url']
            value = response_json['actions'][0]['value']
            resource_type = value.split("resource_type=")[1].split("+")[0]
            decision = value.split("decision=")[1].split("+")[0]

            if resource_type == "google.compute.Firewall" and decision == "Remediate":
                cloud_function = "remediate-firewall"
                http_endpoint = "https://us-central1-secops-project-348011.cloudfunctions.net/remediate-firewall"
            elif resource_type == "google.compute.Instance" and decision == "Remediate":
                cloud_function = "remediate-instance"
                http_endpoint = "https://us-central1-secops-project-348011.cloudfunctions.net/remediate-instance"
            elif resource_type == "google.compute.BackendService" and decision == "Remediate":
                cloud_function = "deactivate-finding"
                http_endpoint = "https://us-central1-secops-project-348011.cloudfunctions.net/deactivate-finding"
            elif decision == "Mute":
                cloud_function = "mute-finding"
                http_endpoint = "https://us-central1-secops-project-348011.cloudfunctions.net/mute-finding"
            else:
                print("Nothing to execute!")
                return {
                    'statusCode': 200,
                }
            
            slack_ack(url)
            response_payload = {
              "caller_name": response_json['user']['name'],
              "caller_id": response_json['user']['id'],
              "value": value,
              "response_url": url
            }
            print(f"Executing function: {cloud_function} initiated by Caller Name: {response_json['user']['name']}, Caller ID: {response_json['user']['id']}")
            response_statuscode = call_function(http_endpoint, response_payload)
            return {
                'statusCode': response_statuscode
            }
        else:
            print("Not a valid payload!")
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

def slack_ack(url):
    ack_message = {
        "response_type": "ephemeral",
        "type": "mrkdwn",
        "text": "Hey, _secops commando_, action is underway!"
    }
    response = requests.post(url, data=json.dumps(ack_message), headers={'Content-Type': 'application/json'})
    print(f"Slack responded with Status Code: {response.status_code}")