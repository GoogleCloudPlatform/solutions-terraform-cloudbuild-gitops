# Cloud Deploy Service Agent
resource "google_project_service_identity" "clouddeploy_service_agent" {
  provider = google-beta

  project = var.project
  service = "clouddeploy.googleapis.com"
}

resource "google_project_iam_member" "clouddeploy_service_agent_role" {
  project = var.project
  role    = "roles/clouddeploy.serviceAgent"
  member  = "serviceAccount:${google_project_service_identity.clouddeploy_service_agent.email}"
}

data "google_project" "project" {
  project_id = var.project
}

data "google_project" "build_project" {
  project_id = var.build_project
}

# Cloud Deploy Execution Service Account
resource "google_service_account" "clouddeploy_execution_sa" {
  project      = var.project
  account_id   = "clouddeploy-execution-sa"
  display_name = "clouddeploy-execution-sa"
}

resource "google_project_iam_member" "cd_sa_iam" {
  project       = var.project
  role          = "roles/clouddeploy.jobRunner"
  member        = "serviceAccount:${google_service_account.clouddeploy_execution_sa.email}"
}

# IAM membership for Cloud Build SA to act as Cloud Deploy Execution SA
resource "google_service_account_iam_member" "cloudbuild_clouddeploy_impersonation" {
  service_account_id = google_service_account.clouddeploy_execution_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_project.build_project.number}@cloudbuild.gserviceaccount.com"
}

# IAM membership for Cloud Deploy Execution SA deploy to GKE
resource "google_project_iam_member" "clouddeploy_gke_dev" {
  project  = var.project
  role     = "roles/container.developer"
  member   = "serviceAccount:${google_service_account.clouddeploy_execution_sa.email}"
}

# IAM membership for Cloud Build SA to deploy to GKE
resource "google_project_iam_member" "gke_dev" {
  project  = var.project
  role     = "roles/container.developer"
  member   = "serviceAccount:${data.google_project.build_project.number}@cloudbuild.gserviceaccount.com"
}

# Custom role for Cloud Build SA
resource "google_project_iam_custom_role" "cb-custom-role" {
  role_id     = "secure_cicd_role"
  title       = "Custom Role for the Secure CICD Cloud Build SA"
  description = "This role is used by the Cloud Build SA in ${var.project}"
  permissions = ["artifactregistry.repositories.create","container.clusters.get","binaryauthorization.attestors.get","binaryauthorization.attestors.list","clouddeploy.deliveryPipelines.get","clouddeploy.releases.get","containeranalysis.notes.attachOccurrence","iam.serviceAccounts.actAs","ondemandscanning.operations.get","ondemandscanning.scans.analyzePackages","ondemandscanning.scans.listVulnerabilities"]
}

resource "google_project_iam_member" "custom_policy" {
  project  = var.project
  role     = "projects/${var.project}/roles/secure_cicd_role"
  member   = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}
