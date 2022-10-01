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
  env                           = "prod"
  clouddeploy_pubsub_topic_name = "clouddeploy-operations"
}

provider "google" {
  project   = var.project
}

provider "google-beta" {
  project   = var.project
  region    = var.region
}

# GCS bucket to store cloud function source codes
resource "google_storage_bucket" "bucket" {
  name                          = "${var.project}-source-code"
  location                      = var.region
  uniform_bucket_level_access   = true
}

module "admin-access-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "admin-access"
    function-desc   = "intakes requests from slack for just-in-time admin access to a project"
    entry-point     = "admin_access"
    env-vars        = {
        SLACK_APPROVER_CHANNEL = var.slack_approver_channel,
        DEPLOYMENT_PROJECT = var.project,
        DEPLOYMENT_REGION = var.region
    }
    secrets         = [
        {
            key = "SLACK_ACCESS_TOKEN"
            id  = google_secret_manager_secret.slack-access-admin-bot-token.secret_id
        },
        {
            key = "SLACK_SIGNING_SECRET"
            id  = google_secret_manager_secret.slack-access-admin-signing-secret.secret_id
        }
    ]
}

# IAM entry for all users to invoke the admin-access function
resource "google_cloudfunctions_function_iam_member" "admin-access-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.admin-access-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

module "provision-access-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "provision-access"
    function-desc   = "processes approvals for just-in-time admin access to a project"
    entry-point     = "provision_access"
    env-vars        = {
        CLOUD_IDENTITY_DOMAIN = var.cloud_identity_domain
    }
}

# IAM entry for service account of admin-access function to invoke the provision-access function
resource "google_cloudfunctions_function_iam_member" "provision-access-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.provision-access-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${module.admin-access-cloud-function.sa-email}"
}

# IAM entry for service account of provision-access function to manage IAM policies
resource "google_organization_iam_member" "organization" {
  org_id    = var.organization
  role      = "roles/resourcemanager.projectIamAdmin"
  member    = "serviceAccount:${module.provision-access-cloud-function.sa-email}"
}

resource "google_secret_manager_secret" "slack-access-admin-bot-token" {
  project   = var.project
  secret_id = "slack-access-admin-bot-token"

  replication {
    automatic = true
  }
}

# IAM entry for service account of admin-access function to use the slack bot token
resource "google_secret_manager_secret_iam_binding" "bot_token_binding" {
  project   = google_secret_manager_secret.slack-access-admin-bot-token.project
  secret_id = google_secret_manager_secret.slack-access-admin-bot-token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.admin-access-cloud-function.sa-email}",
  ]
}

resource "google_secret_manager_secret" "slack-access-admin-signing-secret" {
  project   = var.project
  secret_id = "slack-access-admin-signing-secret"

  replication {
    automatic = true
  }
}

# IAM entry for service account of admin-access function to use the slack signing secret
resource "google_secret_manager_secret_iam_binding" "signing_secret_binding" {
  project   = google_secret_manager_secret.slack-access-admin-signing-secret.project
  secret_id = google_secret_manager_secret.slack-access-admin-signing-secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.admin-access-cloud-function.sa-email}",
  ]
}

resource "google_pubsub_topic" "operations-pubsub" {
  name = "clouddeploy-operations"
  message_retention_duration = "86400s"
}

module "deploy-notification-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "deploy-notification"
    function-desc   = "triggered by operations-pubsub, communicates result of a deployment"
    entry-point     = "deploy_notification"
    pubsub_trigger  = google_pubsub_topic.operations-pubsub.id
    env-vars        = {
        SLACK_SECOPS_CHANNEL = var.slack_secops_channel
    }
    secrets         = [
        {
            key = "SLACK_ACCESS_TOKEN"
            id  = google_secret_manager_secret.slack-secure-cicd-bot-token.secret_id
        }
    ]
}

resource "google_secret_manager_secret" "slack-secure-cicd-bot-token" {
  project   = var.project
  secret_id = "slack-secure-cicd-bot-token"

  replication {
    automatic = true
  }
}

# IAM entry for service account of deploy-notification function to use the slack bot token
resource "google_secret_manager_secret_iam_binding" "cicd_bot_token_binding" {
  project   = google_secret_manager_secret.slack-secure-cicd-bot-token.project
  secret_id = google_secret_manager_secret.slack-secure-cicd-bot-token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.deploy-notification-cloud-function.sa-email}",
  ]
}

resource "google_clouddeploy_target" "dev-cluster-target" {
  name        = "dev-cluster-target"
  description = "Target for dev environment"
  project     = var.project
  location    = var.region

  gke {
    cluster = var.dev_cluster_name
  }

  depends_on = [
    google_project_iam_member.clouddeploy_service_agent_role
  ]
}

resource "google_clouddeploy_delivery_pipeline" "pipeline" {
  name        = "binauthz-demo-pipeline"
  description = "Pipeline for application" #TODO parameterize
  project     = var.project
  location    = var.region

  serial_pipeline {
    stages {
        target_id = google_clouddeploy_target.dev-cluster-target.name
    }
  }
}


# Binary Authorization Policy
resource "google_binary_authorization_policy" "binauthz_policy" {
  project = var.project
  
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google_containers/*"
  }

  default_admission_rule {
    evaluation_mode  = "ALWAYS_ALLOW"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }
  
  cluster_admission_rules {
    cluster                 = "${var.region}.${var.dev_cluster_name}"
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [var.dev_attestor_id]
  }
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

module "http_lb" {
  source  = "../../modules/http_lb"
  project = "${var.project}"
  network  = "${module.vpc.network}"
  instance_template_id = "${module.instance_template.instance_template_id}"
}

module "cloud_nat" {
  source  = "../../modules/cloud_nat"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
}
*/