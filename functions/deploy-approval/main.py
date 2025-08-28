import os
import time
import json
import hmac
import hashlib
import urllib.parse
import requests
from google.cloud import deploy_v1

def deploy_approval(request):
    # extracting payload information from POST
    timestamp = request.headers['X-Slack-Request-Timestamp']
    payload = request.get_data().decode('utf-8')
    slack_signature = request.headers['X-Slack-Signature']
    slack_signing_secret = os.environ.get('SLACK_SIGNING_SECRET')

    if verify_request(timestamp,payload,slack_signature,slack_signing_secret):
        if payload.startswith("payload="):
            # handling the response action
            response_json = json.loads(urllib.parse.unquote(payload.split("payload=")[1]))
            value = response_json['actions'][0]['value']
            print(value)
            rollout = value.split("rollout-name=")[1].split("+")[0]
            deliveryPipeline = value.split("pipeline-name=")[1].split("+")[0]
            location = value.split("region=")[1].split("+")[0]
            release = value.split("release-name=")[1].split("+")[0]
            decision = value.split("decision=")[1].split("+")[0]

            project = os.environ.get('PROJECT_ID')

            slack_ack(response_json['response_url'])
            print(f"Processing deployment {decision} by Caller Name: {response_json['user']['name']}, Caller ID: {response_json['user']['id']}")
            
            # Create a client
            client = deploy_v1.CloudDeployClient()

            # Initialize request argument(s)
            request = deploy_v1.ApproveRolloutRequest(
                name        = f"projects/{project}/locations/{location}/deliveryPipelines/{deliveryPipeline}/releases/{release}/rollouts/{rollout}",
                approved    = True if decision == "Approved" else False,
            )

            # Make the request
            response = client.approve_rollout(request=request)
            
            # Handle the response
            print(response)

            # compose message to respond back to the caller
            slack_message = {
                "attachments": [
                    {
                        "mrkdwn_in": ["text"],
                        "color": "#36a64f",
                        "pretext": f"Approval processed for {deliveryPipeline}!",
                        "title": "Request Details",
                        "fields": [
                            {
                                "title": "Action",
                                "value": decision,
                                "short": True
                            },
                            {
                                "title": "Actioned By",
                                "value": response_json['user']['name'],
                                "short": True
                            }
                        ],
                        "footer": rollout
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

def slack_ack(url):
    ack_message = {
        "response_type": "ephemeral",
        "type": "mrkdwn",
        "text": "Hey, _secops commando_, action is underway!"
    }
    response = requests.post(url, data=json.dumps(ack_message), headers={'Content-Type': 'application/json'})
    print(f"Slack responded with Status Code: {response.status_code}")

def post_slack_response(url, slack_message):
    response = requests.post(url, data=json.dumps(slack_message), headers={'Content-Type': 'application/json'})
    print(f"Message posted - Slack responded with Status Code: {response.status_code}")
    return {
        'statusCode': response.status_code
    }
