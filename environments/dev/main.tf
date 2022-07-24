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
  env = "dev"
}

provider "google" {
  project = var.project
}

module "admin-access-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "admin-access"
    function-desc   = "intakes requests from slack for just-in-time admin access to a project"
    entry-point     = "admin_access"
    secret-id       = google_secret_manager_secret.slack-access-admin-secret.secret_id
}

# IAM entry for all users to invoke the admin-access function
resource "google_cloudfunctions_function_iam_member" "admin-access-invoker" {
  project        = var.project
  region         = "us-central1"
  cloud_function = "admin-access"

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

module "provision-access-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "provision-access"
    function-desc   = "processes approvals for just-in-time admin access to a project"
    entry-point     = "provision_access"
    secret-id       = google_secret_manager_secret.slack-access-admin-secret.secret_id
}

# IAM entry for service account of admin-access function to invoke the provision-access function
resource "google_cloudfunctions_function_iam_member" "provision-access-invoker" {
  project        = var.project
  region         = "us-central1"
  cloud_function = "provision-access"

  role   = "roles/cloudfunctions.invoker"
  member = module.admin-access-cloud-function.sa-email
}

resource "google_secret_manager_secret" "slack-access-admin-secret" {
  project   = var.project
  secret_id = "slack-access-admin-bot-token"

  replication {
    automatic = true
  }
}

# IAM entry for service account of provision-access function to use the slack bot token
resource "google_secret_manager_secret_iam_member" "member" {
  project   = google_secret_manager_secret.slack-access-admin-secret.project
  secret_id = google_secret_manager_secret.slack-access-admin-secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = module.provision-access-cloud-function.sa-email
}

/*
module "vpc" {
  source  = "../../modules/vpc"
  project = "${var.project}"
  env     = "${local.env}"
}

module "instance_template" {
  source  = "../../modules/instance_template"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
}

module "load_balancer" {
  source  = "../../modules/load_balancer"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
  instance_template_id = "${module.instance_template.instance_template_id}"
}

module "cloud_nat" {
  source  = "../../modules/cloud_nat"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
}
*/