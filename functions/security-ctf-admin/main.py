import os
import time
import json
import requests
import google.auth
import googleapiclient.discovery

def security_ctf_admin(request):
    # provisioning the requested access
    event = json.loads(request.get_data().decode('UTF-8'))
    # org_id = os.environ.get('ORG_ID', 'Specified environment variable is not set.')
    ctf_easy_project = os.environ.get('CTF_EASY_PROJECT', 'Specified environment variable is not set.')
    ctf_hard_project = os.environ.get('CTF_HARD_PROJECT', 'Specified environment variable is not set.')
    
    user_email = event['user_email']
    project_id = ctf_easy_project if event['env_name'] == 'easy' else ctf_hard_project
    # org_roles = ["securitycenter.adminViewer", "logging.viewer"] if event['env_name'] == 'easy' else ["logging.viewer"]
    project_roles = ["securitycenter.adminViewer", "logging.viewer", "compute.viewer", "storage.objectViewer"]
    
    try:
        # Initialize service and fetch existing policies
        crm_service     = initialize_service()
        project_policy  = get_project_policy(crm_service, project_id)
        # org_policy      = get_org_policy(crm_service, org_id)

        # Grants your member the requested roles for the project.
        member = f"user:{user_email}"

        # add/remove project-related roles
        for role_name in project_roles:
            role = f"roles/{role_name}"
            project_policy = add_member(project_policy, role, member) if event['action'] == 'grant' else remove_member(project_policy, role, member)
        
        # add/remove org-related roles
        # for role_name in org_roles:
        #     role = f"roles/{role_name}"
        #     org_policy = add_member(org_policy, role, member) if event['action'] == 'grant' else remove_member(org_policy, role, member)
        
        # Update existing policies with new policies
        set_project_policy(crm_service, project_id, project_policy)
        # set_org_policy(crm_service, org_id, org_policy)

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

def get_project_policy(crm_service, project_id) -> dict:
    print(f"Fetching current IAM Policy for Project: {project_id}...")
    policy = (
        crm_service.projects()
        .getIamPolicy(
            resource=project_id,
            body={"options": {"requestedPolicyVersion": 3}},
        )
        .execute()
    )
    return policy

def get_org_policy(crm_service, org_id) -> dict:
    print(f"Fetching current IAM Policy for Org: {org_id}...")
    policy = (
        crm_service.organizations()
        .getIamPolicy(
            resource=f"organizations/{org_id}",
            body={"options": {"requestedPolicyVersion": 3}},
        )
        .execute()
    )
    return policy

def set_project_policy(crm_service, project_id, policy):
    print(f"Setting new IAM Policy for Project: {project_id}...")    
    policy = (
        crm_service.projects()
        .setIamPolicy(
            resource=project_id, 
            body={"policy": policy}
        )
        .execute()
    )

def set_org_policy(crm_service, org_id, policy):
    print(f"Setting new IAM Policy for Org: {org_id}...")    
    policy = (
        crm_service.organizations()
        .setIamPolicy(
            resource=f"organizations/{org_id}", 
            body={"policy": policy}
        )
        .execute()
    )