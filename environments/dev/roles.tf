# google_project_iam_custom_role.dialogflow_gia_client:
resource "google_project_iam_custom_role" "dialogflow_gia_client" {
    description = "Created on: 2020-02-06 Based on: Dialogflow API Admin"
    permissions = [
        "dialogflow.agents.export",
        "dialogflow.agents.get",
        "dialogflow.entityTypes.get",
        "dialogflow.entityTypes.list",
        "dialogflow.intents.get",
        "dialogflow.intents.list",
        "dialogflow.sessionEntityTypes.get",
        "dialogflow.sessionEntityTypes.list",
        "dialogflow.sessions.detectIntent",
        "dialogflow.sessions.streamingDetectIntent",
    ]
    project = var.project
    role_id     = "DialogflowAPIGIAClient"
    stage       = "GA"
    title       = "Dialogflow API GIA CLIENT"
}

# google_project_iam_custom_role.vault_gcp_secret:
resource "google_project_iam_custom_role" "vault_gcp_secret" {
    description = "Used by the vault-gcp-secret service account and grants the permission to Vault for managing service account keys and OAuth2 tokens."
    permissions = [
        "iam.serviceAccountKeys.create",
        "iam.serviceAccountKeys.delete",
        "iam.serviceAccountKeys.get",
        "iam.serviceAccountKeys.list",
        "iam.serviceAccounts.create",
        "iam.serviceAccounts.delete",
        "iam.serviceAccounts.get",
        "iam.serviceAccounts.list",
        "iam.serviceAccounts.update",
    ]
    project = var.project
    role_id     = "vault_gcp_secret"
    title       = "vault_gcp_secret"
}

# google_project_iam_custom_role.vault_gcp_secret_iam:
resource "google_project_iam_custom_role" "vault_gcp_secret_iam" {
    description = "Used by the Vault Secret Engine. Grants getIamPolicy and setIamPolicy permissions."
    permissions = [
        "firebasedatabase.instances.create",
        "firebasedatabase.instances.get",
        "firebasedatabase.instances.list",
        "firebasedatabase.instances.update",
        "resourcemanager.projects.get",
        "resourcemanager.projects.getIamPolicy",
        "resourcemanager.projects.setIamPolicy",
        "serviceusage.apiKeys.get",
        "serviceusage.apiKeys.getProjectForKey",
        "serviceusage.apiKeys.list",
        "serviceusage.operations.get",
        "serviceusage.operations.list",
        "serviceusage.quotas.get",
        "serviceusage.services.get",
        "serviceusage.services.list",
    ]
    project = var.project
    role_id     = "vault_gcp_secret_iam"
    title       = "vault_gcp_secret_iam"
}


