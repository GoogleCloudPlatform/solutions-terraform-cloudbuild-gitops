# Enable services
resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "resourcemanager" {
  service = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "scc" {
  project = var.demo_project
  service = "securitycenter.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "bq_connection" {
  project = var.project
  service = "bigqueryconnection.googleapis.com"
  disable_on_destroy = false
}