import os
import time
import json
import requests
import google.auth
import googleapiclient.discovery

def security_ctf_admin(request):
    # provisioning the requested access
    event = json.loads(request.get_data().decode('UTF-8'))
    ctf_easy_project = os.environ.get('CTF_EASY_PROJECT', 'Specified environment variable is not set.')
    ctf_hard_project = os.environ.get('CTF_HARD_PROJECT', 'Specified environment variable is not set.')

    user_email = event['user_email']
    project_id = ctf_easy_project if event['env_name'] == 'easy' else ctf_hard_project
    role_names = ["securitycenter.adminViewer", "logging.viewer", "compute.viewer", "storage.objectViewer"] 
    
    try:
        # Initialize service and fetch existing policy.
        crm_service = initialize_service()
        policy = get_policy(crm_service, project_id)

        # Grants your member the requested roles for the project.
        member = f"user:{user_email}"

        for role_name in role_names:
            role = f"roles/{role_name}"
            policy = add_member(policy, role, member) if event['action'] == 'grant' else remove_member(policy, role, member)
        
        # Update existing policy with new policy.
        set_policy(crm_service, project_id, policy)
        result = "Success"
        info = f"{event['action']}: Successful"
    except Exception as error:
        print(f"{role_name} role to project {project_id} {event['action']} failed for {user_email}! - {error}")
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
'''
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
'''
def add_member(policy: dict, role: str, member: str) -> dict:
    print(f"Adding {member} to role {role}...")
    binding = {
        "role": role, 
        "members": [member]
    }
    policy["bindings"].append(binding)
    policy['version'] = 3
    return policy

def remove_member(policy: dict, role: str, member: str) -> dict:
    print(f"Removing {member} from role {role}...")
    binding = next(b for b in policy["bindings"] if b["role"] == role)
    if "members" in binding and member in binding["members"]:
        binding["members"].remove(member)
    return policy

def get_policy(crm_service, project_id) -> dict:
    print(f"Fetching current IAM Policy for project: {project_id}...")
    policy = (
        crm_service.projects()
        .getIamPolicy(
            resource=project_id,
            body={"options": {"requestedPolicyVersion": 3}},
        )
        .execute()
    )
    return policy

def set_policy(crm_service, project_id, policy):
    print(f"Setting new IAM Policy for project: {project_id}...")    
    policy = (
        crm_service.projects()
        .setIamPolicy(
            resource=project_id, 
            body={"policy": policy}
        )
        .execute()
    )