##### Credit Approval - Webapp #####


provider "google" {
   project = "${var.project_id}"
   region  = "${var.region}"
}


terraform {
  backend "gcs" {
    bucket  = "tf-state-cap-dev"
    prefix  = "terraform/state"
  }
}


# Creating service account 

resource "google_service_account" "sa-credit-approval-app" {
    account_id   = "sa-credit-approval-app"
    display_name = "Service Account for Credit Approval App"
}

# Adding iam role for service account 

resource "google_project_iam_member" "sa-credit-approval-app-pubsub-publisher" {
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.sa-credit-approval-app.email}"
}


resource "google_cloud_run_service" "credit-approval-app" {
    name     = "credit-approval-app"
    location = "${var.region}"
    autogenerate_revision_name = true
    template {
        spec {
            containers {
                image = "eu.gcr.io/${var.project_id}/gcr/creditwebapp"  
                resources {
                    limits = {
                      memory = "2048Mi"
                      cpu    = "1000m"
                    }
                  }
                }
            service_account_name = "sa-credit-approval-app@${var.project_id}.iam.gserviceaccount.com"
            timeout_seconds = 800
            }
        metadata {
            annotations = {
                    "autoscaling.knative.dev/minScale" = "0",
                    "autoscaling.knative.dev/maxScale" = "1"
                }
            }
        }
    traffic {
        percent = 100
        latest_revision = true
        }

}