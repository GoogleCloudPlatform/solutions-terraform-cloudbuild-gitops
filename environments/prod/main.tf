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

module "vpc" {
  source  = "../../modules/vpc"
  project = "${var.project}"
  env     = "${local.env}"
}

module "http_server" {
  source  = "../../modules/http_server"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
}

module "firewall" {
  source  = "../../modules/firewall"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
}

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

module "hello_world_pipeline" {
  source = "teamdatatonic/scheduled-vertex-pipelines/google"
  project = "${var.project}"
  vertex_region = "europe-west4"
  cloud_scheduler_region = "europe-west4"
  pipeline_spec_path = "gs://df-data-science-test/prod/basic_pipeline.json"
  gcs_output_directory = "gs://df-data-science-test/prod/out/"
  # vertex_service_account_email = "my-vertex-service-account@my-gcp-project-id.iam.gserviceaccount.com"
  time_zone                    = "UTC"
  schedule                     = "0 0 * * *"
  cloud_scheduler_job_name     = "pipeline-from-local-spec"
}
