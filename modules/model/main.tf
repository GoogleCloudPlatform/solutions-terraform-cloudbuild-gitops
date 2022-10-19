# Creates the workbench instance

resource "google_notebooks_instance" "main" {
  name                  = var.model_name
  project               = var.project
  location              = "europe-west4-a"
  machine_type          = var.machine_type
  install_gpu_driver    = var.gpu_count == 0 ? false : true

  dynamic "accelerator_config" {
    for_each = var.gpu_count == 0 ? [] : [1]
    content {
      type             = var.gpu_type
      core_count       = var.gpu_count
    }
  }

  instance_owners       = var.instance_owners
  container_image {
    repository  = "gcr.io/deeplearning-platform-release/tf2-gpu.2-10"
    tag         = "latest"
  }
  metadata = {
    terraform = "true"
  }
}

locals {
  request_body = {
    url = "https://europe-west4-aiplatform.googleapis.com/v1/projects/${var.project}/locations/europe-west4/pipelineJobs"
    gcs_bucket = var.pipeline_bucket
    gcs_pipeline = "${var.model_name}/pipeline.json"
  }
}

resource "google_cloud_scheduler_job" "job" {
  name = "${var.model_name}"
  project = var.project
  schedule = "0 0 * * *" 
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

// Build trigger for model pipeline
/*
resource "google_cloudbuild_trigger" "main" {
  name              = var.model_name
  filename          = "models/${var.model_name}/cloudbuild.yaml"
  included_files    = [ "models/${var.model_name}/**" ]
  github {
    owner   = "OlavHN"
    name    = "solutions-terraform-cloudbuild-gitops"
    push {
      branch    = "prod"
    }
  }
}
*/

resource "google_cloudbuild_trigger" "main" {
  name              = var.model_name
  filename          = fileexists("models/${var.model_name}/cloudbuild.yaml") ? "models/${var.model_name}/cloudbuild.yaml" : "models/cloudbuild.yaml"
  included_files    = [ "models/${var.model_name}/**" ]
  github {
    owner   = "OlavHN"
    name    = "solutions-terraform-cloudbuild-gitops"
    push {
      branch    = "prod"
    }
  }
}

