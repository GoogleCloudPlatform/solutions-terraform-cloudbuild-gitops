import time
import json
import requests
import google.auth
import googleapiclient.discovery
from pytz import timezone
from datetime import datetime, timedelta

def provision_access(request):
    # provisioning the requested access
    event = json.loads(request.get_data().decode('UTF-8'))

    requestor_name = event['value'].split("requestor_name=")[1].split("+")[0]
    requestor_email = requestor_name + "@agarsand.altostrat.com"
    project_id = event['value'].split("project_id=")[1].split("+")[0]
    duration_hours = event['value'].split("duration_hours=")[1].split("+")[0]
    duration_mins = event['value'].split("duration_mins=")[1].split("+")[0]
    
    access_expiry = datetime.now() + timedelta(hours=duration_hours, minutes=duration_mins)
    expiry_timestamp = access_expiry.strftime('%Y-%m-%dT%H:%M:%SZ')
    expiry_timestamp_ist = access_expiry(timezone("Asia/Kolkata")).strftime('%Y-%m-%d %H:%M:%S')

    try:
        set_iam_policy(project_id, requestor_email, expiry_timestamp)
        response_subject = f"Access provisioned successfully for {requestor_email}!"
    except Exception as e:
        print(e)
        response_subject = f"Access provisioning failed for {requestor_email}!"

    slack_message = {
        "text": f"{response_subject}\n",
        "blocks": [ 
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": "Access Provisioning Action Taken"
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
                        "text": f"*Project:*\n{project_id}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Expiry:*\n{expiry_timestamp_ist} IST"
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

def set_iam_policy(project_id, requestor_email, expiry_timestamp):
    try:
        print(f"Creating IAM Policy...")
        # Role to be granted.
        role = "roles/editor"

        # Initializes service.
        crm_service = initialize_service()

        # Grants your member the 'Log Writer' role for the project.
        member = f"user:{requestor_email}"
        policy = modify_policy_add_role(crm_service, project_id, role, member, expiry_timestamp)
        print(policy)
    except Exception as e:
        raise(e)

def post_slack_response(response_url,slack_message):
    response = requests.post(response_url, data=json.dumps(slack_message), headers={'Content-Type': 'application/json'})
    if response.status_code == 200:
        print("Slack response sent successfully.")
        return True
    else:
        print("Slack response failed.")
        return False

def initialize_service():
    """Initializes a Cloud Resource Manager service."""

    credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    crm_service = googleapiclient.discovery.build(
        "cloudresourcemanager", "v1", credentials=credentials
    )
    return crm_service

def modify_policy_add_role(crm_service, project_id, role, member, expiry_timestamp):
    """Adds a new role binding to a policy."""

    """Gets IAM policy for a project."""
    policy = (
        crm_service.projects()
        .getIamPolicy(
            resource=project_id,
            body={"options": {"requestedPolicyVersion": 3}},
        )
        .execute()
    )

    binding = None
    for b in policy["bindings"]:
        if b["role"] == role:
            binding = b
            break
    if binding is not None:
        binding["members"].append(member)
    else:
        binding = {
            "role": role, 
            "members": [member], 
            "condition": {
                "title": "expirable access", 
                "description": f"Does not grant access after {expiry_timestamp}",
                "expression": f"request.time < timestamp('f{expiry_timestamp}')"
            }
        }
        policy["bindings"].append(binding)

    """Sets IAM policy for a project."""
    policy = (
        crm_service.projects()
        .setIamPolicy(
            resource=project_id, 
            body={"policy": policy})
        .execute()
    )
    return policy
