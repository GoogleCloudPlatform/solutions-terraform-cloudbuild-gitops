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
