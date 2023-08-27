import os
import time
import json
import requests
import google.auth
import googleapiclient.discovery
from pytz import timezone
from datetime import datetime, timedelta

def security_ctf_admin(request):
    # provisioning the requested access
    event = json.loads(request.get_data().decode('UTF-8'))
    ctf_easy_project = os.environ.get('CTF_EASY_PROJECT', 'Specified environment variable is not set.')
    ctf_hard_project = os.environ.get('CTF_HARD_PROJECT', 'Specified environment variable is not set.')

    user_email = event['user_email']
    project_id = ctf_easy_project if event['env_name'] == 'easy' else ctf_hard_project
    role_name = "viewer"
    duration_hours = 2
    duration_mins = 0
    
    expiry_timestamp = (datetime.now() + timedelta(hours=float(duration_hours), minutes=float(duration_mins))).strftime('%Y-%m-%dT%H:%M:%SZ')
    expiry_timestamp_ist = (datetime.now(timezone('Asia/Kolkata')) + timedelta(hours=float(duration_hours), minutes=float(duration_mins))).strftime('%Y-%m-%d %H:%M:%S')

    try:
        # Role to be granted.
        role = f"roles/{role_name}"
        
        # Initializes service.
        crm_service = initialize_service()

        # Grants your member the requested role for the project.
        member = f"user:{user_email}"
        modify_policy_add_role(crm_service, project_id, role, member, expiry_timestamp)
        print(f"{role_name} role to project {project_id} provisioned successfully for {user_email}!")
        result = "Success"
        info = f"Expiry: {expiry_timestamp_ist}"
    except Exception as error:
        print(f"{role_name} role to project {project_id} provisioning failed for {user_email}! - {error}")
        result = "Failure"
        info = f"Error: {error}"
    
    data = {
        "result": result, 
        "info": info
    }
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
    
    binding = {
        "role": role, 
        "members": [member], 
        "condition": {
            "title": "expirable access", 
            "description": f"Does not grant access after {expiry_timestamp}",
            "expression": f"request.time < timestamp(\"{expiry_timestamp}\")"
        }
    }
    policy["bindings"].append(binding)
    policy['version'] = 3

    print(f"Setting new IAM Policy for project: {project_id}...")
    policy = (
        crm_service.projects()
        .setIamPolicy(
            resource=project_id, 
            body={"policy": policy})
        .execute()
    )
