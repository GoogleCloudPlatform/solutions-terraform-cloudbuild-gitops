import os
import json
import google.auth
import googleapiclient.discovery

def security_ctf_admin(request):
    # provisioning the requested access
    event = json.loads(request.get_data().decode('UTF-8'))
    # org_id = os.environ.get('ORG_ID', 'Specified environment variable is not set.')
    ctf_easy_project = os.environ.get('CTF_EASY_PROJECT', 'Specified environment variable is not set.')
    ctf_hard_project = os.environ.get('CTF_HARD_PROJECT', 'Specified environment variable is not set.')
    storage_role     = os.environ.get('STORAGE_ROLE', 'Specified environment variable is not set.')
    
    project_id = ctf_easy_project if event['env_name'] == 'easy' else ctf_hard_project
    # org_roles = ["securitycenter.adminViewer", "logging.viewer"] if event['env_name'] == 'easy' else ["logging.viewer"]
    predefined_roles = ["iam.securityReviewer", "cloudsecurityscanner.viewer", "compute.viewer", "bigquery.dataViewer", "bigquery.user", "dlp.reader", "monitoring.viewer"]
    custom_roles = [storage_role]

    try:
        # initialize service and the user principal that needs access
        crm_service = initialize_service()
        member      = f"user:{event['user_email']}"

        # add/remove project-related roles from the Project IAM policy
        project_policy  = get_project_policy(crm_service, project_id)
        project_policy  = add_member(project_policy, predefined_roles, custom_roles, member) if event['action'] == 'Grant' else remove_member(project_policy, predefined_roles, custom_roles, member)
        set_project_policy(crm_service, project_id, project_policy)

        '''
        # add/remove org-related roles from the Org IAM policy
        org_policy      = get_org_policy(crm_service, org_id)
        for role_name in org_roles:
            role = f"roles/{role_name}"
            org_policy = add_member(org_policy, role, member) if event['action'] == 'Grant' else remove_member(org_policy, role, member)
        set_org_policy(crm_service, org_id, org_policy)
        '''

        info = f"{event['action']}: Successful"
    except Exception as error:
        print(f"{event['action']} to {event['env_name']} failed for {event['user_email']}! - {error}")
        info = f"Error: {error}"
    
    data = {
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

def add_member(policy: dict, predefined_roles: list, custom_roles: list, member: str) -> dict:
    for role_name in predefined_roles:
        role = f"roles/{role_name}"
        print(f"Adding {member} to role {role}...")
        binding = {
            "role": role, 
            "members": [member]
        }
        policy["bindings"].append(binding)
    
    for role in custom_roles:
        print(f"Adding {member} to role {role}...")
        binding = {
            "role": role, 
            "members": [member]
        }
        policy["bindings"].append(binding)
    
    policy['version'] = 3
    return policy

def remove_member(policy: dict, predefined_roles: list, custom_roles: list, member: str) -> dict:
    for role_name in predefined_roles:
        role = f"roles/{role_name}"
        print(f"Removing {member} from role {role}...")
        binding = next(b for b in policy["bindings"] if b["role"] == role)
        if "members" in binding and member in binding["members"]:
            binding["members"].remove(member)
    
    for role in custom_roles:
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