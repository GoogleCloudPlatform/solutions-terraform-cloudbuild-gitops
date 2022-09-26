# Enable services
resource "google_project_service" "compute" {
  project = var.project
  service = "compute.googleapis.com"
}

resource "google_project_service" "managed_kubernetes" {
  project = var.project
  service = "container.googleapis.com"
}
