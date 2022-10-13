# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


locals {
  env = "prod"
}

provider "google" {
  project = "${var.project}"
}

// Models TODO: iterate over yaml config files in folders
module "model" {
  source        = "../../modules/model"
  model_name    = "module-model-test"
  project       = var.project
  gpu_count     = 1
}

// BEGIN STATIC CONFIG

// Artifact repository
resource "google_artifact_registry_repository" "main" {
  location      = "europe-west4"
  repository_id = "df-ds-repo"
  description   = "Docker repository"
  format        = "DOCKER"
}

// Build trigger for pipeline_scheduler Docker image changes
resource "google_cloudbuild_trigger" "scheduler" {
  name              = "scheduler"
  filename          = "run/pipeline_scheduler/cloudbuild.yaml"
  included_files    = [ "run/pipeline_scheduler/**" ]
  github {
    owner   = "OlavHN"
    name    = "solutions-terraform-cloudbuild-gitops"
    push {
      branch    = "prod|dev"
    }
  }
}

// Build trigger for folder. TODO: Add to model module
resource "google_cloudbuild_trigger" "pipeline" {
  name = "pipeline"
  filename = "pipeline/cloudbuild.yaml"
  included_files = [ "pipeline/**" ]
  github {
    owner = "OlavHN"
    name = "solutions-terraform-cloudbuild-gitops"
    push {
      branch = "prod|dev"
    }
  }
}


/*
module "workbench" {
  source  = "../../modules/workbench"
  project = "${var.project}"
}

resource "google_storage_bucket" "auto-expire" {
  name          = "df-data-science-test-pipelines"
  location      = "europe-west4"
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 3
    }
    action {
      type = "Delete"
    }
  }
}

#module "working_pipeline" {
#  source = "teamdatatonic/scheduled-vertex-pipelines/google"
#  project = "${var.project}"
#  vertex_region = "europe-west4"
#  cloud_scheduler_region = "europe-west1"
#  pipeline_spec_path = "gs://df-data-science-test-pipelines/prod/pipeline.json"
#  parameter_values = {}
#  gcs_output_directory = "gs://df-data-science-test-pipelines/prod/out/"
#  vertex_service_account_email = "364866568815-compute@developer.gserviceaccount.com"
#  time_zone                    = "UTC"
#  schedule                     = "0 0 * * *"
#  cloud_scheduler_job_name     = "working-pipeline-schedule"
#}
#
#module "not_working_pipeline" {
#  source = "teamdatatonic/scheduled-vertex-pipelines/google"
#  project = "${var.project}"
#  vertex_region = "europe-west4"
#  cloud_scheduler_region = "europe-west1"
#  pipeline_spec_path = "gs://df-data-science-test-pipelines/prod/pipeline3.json"
#  parameter_values = {
#    "a" = "Hello, world!"
#    "b" = "Hello, world!"
#  }
#  gcs_output_directory = "gs://df-data-science-test-pipelines/prod/out/"
#  vertex_service_account_email = "364866568815-compute@developer.gserviceaccount.com"
#  time_zone                    = "UTC"
#  schedule                     = "0 0 * * *"
#  cloud_scheduler_job_name     = "not-working-pipeline-schedule"
#}


#module "real_pipeline" {
#  source = "teamdatatonic/scheduled-vertex-pipelines/google"
#  project = "${var.project}"
#  vertex_region = "europe-west4"
#  cloud_scheduler_region = "europe-west1"
#  pipeline_spec_path = "gs://df-data-science-test-pipelines/prod/pipeline.json"
#  parameter_values = {
#    "project" = "df-data-science-test"
#  }
#  gcs_output_directory = "gs://df-data-science-test-pipelines/prod/out/"
#  vertex_service_account_email = "364866568815-compute@developer.gserviceaccount.com"
#  time_zone                    = "UTC"
#  schedule                     = "0 0 * * *"
#  cloud_scheduler_job_name     = "real-pipeline-schedule"
#}

# Attempt our own implementation

data "google_storage_bucket_object_content" "pipeline_spec" {
  name   = "prod/pipeline.json"
  bucket = "df-data-science-test-pipelines"
}

locals {
  pipeline_spec = jsondecode(data.google_storage_bucket_object_content.pipeline_spec.content)

  pipeline_job = {
    displayName = "self-made-pipeline"
    pipelineSpec = local.pipeline_spec
    labels       = {}
#    runtimeConfig = {
#      parameterValues    = {
#        # "text" = "hello world!"
#        "a" = "a inp"
#        "b" = "b inp"
#      }
#      gcsOutputDirectory = "gs://df-data-science-test-pipelines/prod/out/"
#    }
    encryptionSpec = null
    serviceAccount = "364866568815-compute@developer.gserviceaccount.com"
    # network        = var.network
  }

  merged_job = merge(local.pipeline_spec, local.pipeline_job)
}

resource "google_cloud_scheduler_job" "job" {
  name = "self-made-job-reread"
  project = "${var.project}"
  description = "Our very own scheduled job"
  schedule = "0 0 * * *" 
  time_zone = "UTC"
  attempt_deadline = "320s"
  region = "europe-west1"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = "https://europe-west4-aiplatform.googleapis.com/v1/projects/${var.project}/locations/europe-west4/pipelineJobs"
    body        = base64encode(jsonencode(local.pipeline_spec))

    oauth_token {
      service_account_email = "364866568815-compute@developer.gserviceaccount.com"
    }
  }
}

*/
