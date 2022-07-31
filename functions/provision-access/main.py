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
    requestor_email = "slack@agarsand.altostrat.com"
    project_id = event['value'].split("project_id=")[1].split("+")[0]
    duration_hours = event['value'].split("duration_hours=")[1].split("+")[0]
    duration_mins = event['value'].split("duration_mins=")[1].split("+")[0]
    
    expiry_timestamp = (datetime.now() + timedelta(hours=float(duration_hours), minutes=float(duration_mins))).strftime('%Y-%m-%dT%H:%M:%SZ')
    expiry_timestamp_ist = (datetime.now(timezone('Asia/Kolkata')) + timedelta(hours=float(duration_hours), minutes=float(duration_mins))).strftime('%Y-%m-%d %H:%M:%S')

    try:
        # Role to be granted.
        role = "roles/editor"
        
        # Initializes service.
        crm_service = initialize_service()

        # Grants your member the 'Editor' role for the project.
        member = f"user:{requestor_email}"
        modify_policy_add_role(crm_service, project_id, role, member, expiry_timestamp)
        response_subject = f"Access provisioned successfully for {requestor_name}!"
    except Exception as e:
        print(e)
        response_subject = f"Access provisioning failed for {requestor_name}!"
    
    data = {
        "response_subject": response_subject, 
        "expiry_timestamp_ist": expiry_timestamp_ist
    }
    print(data)
    return json.dumps(data), 200, {'Content-Type': 'application/json'}

def initialize_service():
    print("Initializing Cloud Resource Manager service...")
    credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    crm_service = googleapiclient.discovery.build(
        "cloudresourcemanager", "v1", credentials=credentials
    )
    return crm_service

def modify_policy_add_role(crm_service, project_id, role, member, expiry_timestamp):
    print(f"Fetching current IAM Policy for project: {project_id}...")
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
                "expression": f"request.time < timestamp('{expiry_timestamp}')"
            }
        }
        policy["bindings"].append(binding)

    print(f"Setting new IAM Policy for project: {project_id}...")
    policy = (
        crm_service.projects()
        .setIamPolicy(
            resource=project_id, 
            body={"policy": policy})
        .execute()
    )
