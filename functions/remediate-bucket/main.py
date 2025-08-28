import time
import json
import requests
from google.cloud import storage
from pytz import timezone 
from datetime import datetime

def remediate_bucket(request):
    # processing the remediate_bucket request
    event = json.loads(request.get_data().decode('UTF-8'))
    response_timestamp = datetime.now(timezone("Asia/Kolkata")).strftime('%Y-%m-%d %H:%M:%S')
    project_name = event['value'].split("project_name=")[1].split("+")[0]
    resource_name = event['value'].split("resource_name=")[1].split("+")[0]
    #resource_id = event['value'].split("resource_id=")[1].split("+")[0]

    result = remove_bucket_iam_member(resource_name)
    if result:
        response_subject = "Public Access to the bucket removed successfully!"
    else:
        response_subject = "Public Access to the bucket removal failed!"

    slack_message = {
        "text": f"{response_subject}\n",
        "blocks": [ 
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": "Remediate Action Taken"
                }
            },
            {
                "type": "divider"
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"{response_subject}\n"
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*Requestor:*\n{event['caller_name']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*When:*\n{response_timestamp} IST"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Project:*\n{project_name}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Resource:*\n{resource_name}"
                    }
                ]
            }
        ]
    }
    post_slack_response(event['response_url'],slack_message)
    return {
        'statusCode': 200,
        'body': json.dumps("Completed!")
    }

def remove_bucket_iam_member(bucket_name):
    """Remove member from bucket IAM Policy"""
    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket(bucket_name)

        policy = bucket.get_iam_policy(requested_policy_version=3)

        for binding in policy.bindings:
            print(binding)
            if "allUsers" in binding["members"]:
                binding["members"].discard("allUsers")
                print(f"Removed allUsers with role {binding['role']} from {bucket_name}.")
            if "allAuthenticatedUsers" in binding["members"]:
                binding["members"].discard("allAuthenticatedUsers")
                print(f"Removed allAuthenticatedUsers with role {binding['role']} from {bucket_name}.")

        bucket.set_iam_policy(policy)
        return True
    except Exception as e:
        print(e)
        return False

def post_slack_response(response_url,slack_message):
    response = requests.post(response_url, data=json.dumps(slack_message), headers={'Content-Type': 'application/json'})
    if response.status_code == 200:
        print("Slack response sent successfully.")
        return True
    else:
        print("Slack response failed.")
        return False