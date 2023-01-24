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

# Create a custom IAM role
resource "google_project_iam_custom_role" "cb-custom-role" {
  role_id     = "secure_cicd_role"
  title       = "Custom Role for the Secure CICD Cloud Build SA"
  description = "This role is used by the Cloud Build SA in ${var.project}"
  permissions = ["artifactregistry.repositories.create","container.clusters.get","binaryauthorization.attestors.get","binaryauthorization.attestors.list","clouddeploy.deliveryPipelines.get","clouddeploy.releases.get","clouddeploy.releases.create","clouddeploy.operations.get","cloudkms.cryptoKeyVersions.useToSign","cloudkms.cryptoKeyVersions.viewPublicKey","serviceusage.services.enable","storage.objects.get","containeranalysis.notes.attachOccurrence","containeranalysis.notes.create","containeranalysis.notes.listOccurrences","containeranalysis.notes.setIamPolicy","iam.serviceAccounts.actAs","ondemandscanning.operations.get","ondemandscanning.scans.analyzePackages","ondemandscanning.scans.listVulnerabilities"]
}

# Grant the custom IAM role and Cloud Deploy Admin for Cloud Build SA
resource "google_project_iam_member" "custom_iam_role" {
  project  = var.project
  role     = "projects/${var.project}/roles/secure_cicd_role"
  member   = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloud_deploy_admin" {
  project  = var.project
  role     = "roles/clouddeploy.admin"
  member   = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Cloud Deploy Execution Service Account
resource "google_service_account" "clouddeploy_execution_sa" {
  project      = var.project
  account_id   = "clouddeploy-execution-sa"
  display_name = "clouddeploy-execution-sa"
}

# IAM membership for Cloud Build SA to act as Cloud Deploy Execution SA
resource "google_service_account_iam_member" "cloudbuild_clouddeploy_impersonation" {
  service_account_id = google_service_account.clouddeploy_execution_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# IAM membership for Cloud Deploy Execution SA deploy to GKE and execute jobs
resource "google_project_iam_member" "clouddeploy_gke_dev" {
  project  = var.project
  role     = "roles/container.developer"
  member   = "serviceAccount:${google_service_account.clouddeploy_execution_sa.email}"
}

resource "google_project_iam_member" "clouddeploy_job_runner" {
  project   = var.project
  role      = "roles/clouddeploy.jobRunner"
  member    = "serviceAccount:${google_service_account.clouddeploy_execution_sa.email}"
}

# IAM membership for Binary Authorization service agents in GKE projects on attestors
resource "google_project_service_identity" "binauth_service_agent" {
  provider  = google-beta
  project   = var.project
  service   = "binaryauthorization.googleapis.com"
}

resource "google_binary_authorization_attestor_iam_member" "binauthz_verifier" {
  project  = var.project
  attestor = google_binary_authorization_attestor.attestor.id
  role     = "roles/binaryauthorization.attestorsVerifier"
  member   = "serviceAccount:${google_project_service_identity.binauth_service_agent.email}"
}
