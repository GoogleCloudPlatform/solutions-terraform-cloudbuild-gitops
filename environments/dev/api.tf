# google_project_service.cloudresourcemanager:
resource "google_project_service" "cloudresourcemanager" {
    //id      = "cloudresourcemanager.googleapis.com"
    //project = "ingka-isx-contact-dev"
    project = var.project
    service = "cloudresourcemanager.googleapis.com"
    disable_on_destroy = true

    timeouts {}
}

# google_project_service.dialogflow:
resource "google_project_service" "dialogflow" {
    project = var.project
    service = "dialogflow.googleapis.com"
    disable_on_destroy = true

    timeouts {}
}

# google_project_service.iam:
resource "google_project_service" "iam" {
    project = var.project
    service = "iam.googleapis.com"
    disable_on_destroy = true

    timeouts {}
}