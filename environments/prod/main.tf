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

  model_config_files = fileset(path.module, "../../models/*/config.yaml")

  model_configs = { for config_file in local.model_config_files:
                    config_file => merge(yamldecode(file(config_file)), {model_name=basename(dirname(config_file))})}

  workbench_config_files = fileset(path.module, "../../workbenches/*/config.yaml")

  workbench_configs = { for config_file in local.workbench_config_files:
                    config_file => merge(yamldecode(file(config_file)), {model_name=basename(dirname(config_file))})}

}

provider "google" {
  project = "${var.project}"
}

module "model" {
  source            = "../../modules/model"

  for_each          = local.model_configs

  model_name        = each.value.model_name
  project           = var.project
  gpu_count         = try(each.value.gpu_count, 0)
  pipeline_endpoint = google_cloud_run_service.scheduler.status[0].url
  pipeline_bucket   = google_storage_bucket.pipeline_bucket.name
  cron_schedule     = try(each.value.cron_schedule, "0 0 5 31 2 ?")
}

module "workbench" {
  source            = "../../modules/workbench"

  for_each          = local.workbench_configs

  model_name        = each.value.model_name
  project           = var.project
  gpu_count         = try(each.value.gpu_count, 0)
  gpu_type          = try(each.value.gpu_type, "NVIDIA_TESLA_T4")
  machine_type      = try(each.value.machine_type, "n1-standard-1")
  container         = try(each.value.container, "gcr.io/deeplearning-platform-release/tf2-gpu.2-10")
  tag               = try(each.value.tag, "latest")
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

// Cloud run scheduler service
resource "google_cloud_run_service" "scheduler" {
  name     = "cloudrun-scheduler"
  location = "europe-west4"

  template {
    spec {
      containers {
        image = "europe-west4-docker.pkg.dev/df-data-science-test/df-ds-repo/scheduler:latest"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_storage_bucket" "pipeline_bucket" {
    name     = "${var.project}-pipelines"
    location = "europe-west4"
}

resource "google_storage_bucket" "data_bucket" {
    name     = "${var.project}-data"
    location = "europe-west4"
}

