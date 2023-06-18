# Enable services
resource "google_project_service" "compute" {
  project = var.project
  service = "compute.googleapis.com"
}

resource "google_project_service" "functions" {
  project = var.project
  service = "cloudfunctions.googleapis.com"
}

resource "google_project_service" "kms" {
  project = var.project
  service = "cloudkms.googleapis.com"
}

resource "google_project_service" "managed_kubernetes" {
  project = var.project
  service = "container.googleapis.com"
}

resource "google_project_service" "binauthz" {
  project = var.project
  service = "binaryauthorization.googleapis.com"
}

resource "google_project_service" "artifact_registry" {
  project = var.project
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "cloud_build" {
  project = var.project
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "cloud_deploy" {
  project = var.project
  service = "clouddeploy.googleapis.com"
}

resource "google_project_service" "ondemand_scanning" {
  project = var.project
  service = "ondemandscanning.googleapis.com"
}

resource "google_project_service" "container_scanning" {
  project = var.project
  service = "containerscanning.googleapis.com"
}

resource "google_project_service" "data_loss_prevention" {
  project = var.project
  service = "dlp.googleapis.com"
}

resource "google_project_service" "cloud_sql" {
  project = var.project
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "iap" {
  project = var.project
  service = "iap.googleapis.com"
}
