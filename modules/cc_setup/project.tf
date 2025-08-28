# Enable services
resource "google_project_service" "cloud_apis" {
  project = var.project
  service = "cloudapis.googleapis.com"
}

resource "google_project_service" "kms" {
  project = var.project
  service = "cloudkms.googleapis.com"
}

resource "google_project_service" "resource_manager" {
  project = var.project
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "cloud_shell" {
  project = var.project
  service = "cloudshell.googleapis.com"
}

resource "google_project_service" "managed_kubernetes" {
  project = var.project
  service = "container.googleapis.com"
}

resource "google_project_service" "artifact_registry" {
  project = var.project
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "iam" {
  project = var.project
  service = "iam.googleapis.com"
}

resource "google_project_service" "confidential_computing" {
  project = var.project
  service = "confidentialcomputing.googleapis.com"
}
