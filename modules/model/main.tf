
locals {
  request_body = {
    url = "https://europe-west4-aiplatform.googleapis.com/v1/projects/${var.project}/locations/europe-west4/pipelineJobs"
    gcs_bucket = var.pipeline_bucket
    gcs_pipeline = "${var.model_name}/pipeline.json"
  }
}


resource "google_cloud_scheduler_job" "job" {
  name = var.model_name
  project = var.project
  schedule = var.cron_schedule
  time_zone = "Europe/Oslo"
  attempt_deadline = "320s"
  region = "europe-west1"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = var.pipeline_endpoint
    body        = base64encode(jsonencode(local.request_body))

    headers = {
      "Content-Type"    = "application/json"
    }

    oidc_token {
      service_account_email = "364866568815-compute@developer.gserviceaccount.com"
    }
  }
}

resource "google_cloudbuild_trigger" "main" {
  name              = var.model_name
  filename          = fileexists("${path.root}/../../models/${var.model_name}/cloudbuild.yaml") ? "models/${var.model_name}/cloudbuild.yaml" : "models/cloudbuild.yaml"
  included_files    = [ "models/${var.model_name}/**" ]
  github {
    owner   = "OlavHN"
    name    = "solutions-terraform-cloudbuild-gitops"
    push {
      branch    = "prod"
    }
  }
}

