# google_service_account.gia-chatbot:
resource "google_service_account" "gia-chatbot" {
    account_id   = var.gia_account_id
    description  = "The service account for Genesys Intelligent Automation"
    display_name = var.gia_account_id
    project = var.project

    timeouts {}
}

# google_service_account.vault-gcp-secret:
resource "google_service_account" "vault-gcp-secret" {
    account_id   = "vault-gcp-secret"
    description  = "Used by Vault for the GCP Secret Engine."
    display_name = "vault-gcp-secret"
    project = var.project

    timeouts {}
}

# google_service_account.terraform:
resource "google_service_account" "terraform" {
    account_id   = "terraform"
    description  = "Used by Terraform to manage IaC configurations."
    display_name = "terraform"
    project = var.project

    timeouts {}
}


/*
resource "google_service_account" "vault_gcp_secret" {
  account_id   = var.vault_service_account
  display_name = var.vault_service_account
  description  = "Used by Vault for the GCP Secret Engine."
}

resource "google_project_iam_member" "vault_gcp_secret" {
  role   = google_project_iam_custom_role.vault_gcp_secret.name
  member = "serviceAccount:${google_service_account.vault_gcp_secret.email}"
}

resource "google_project_iam_member" "vault_gcp_secret_iam" {
  role   = google_project_iam_custom_role.vault_gcp_secret_iam.name
  member = "serviceAccount:${google_service_account.vault_gcp_secret.email}"
}

resource "google_service_account_key" "vault_gcp_secret_key" {
  service_account_id = google_service_account.vault_gcp_secret.name
}

*/