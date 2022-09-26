# Enable services
resource "google_project_service" "compute" {
  project = var.project
  service = "compute.googleapis.com"
}

resource "google_project_service" "managed_kubernetes" {
  project = var.project
  service = "container.googleapis.com"
}

resource "google_project_service" "kms" {
  project = var.project
  service = "cloudkms.googleapis.com"
}

resource "google_project_service" "binauthz" {
  project = var.project
  service = "binaryauthorization.googleapis.com"
}

resource "google_project_service" "artifact_registry" {
  project = var.project
  service = "artifactregistry.googleapis.com"
}
