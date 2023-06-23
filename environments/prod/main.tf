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
  attestor_name                 = "build-attestor"
  deployment_clusters = {
    dev : {
      cluster_name    = "dev-binauthz"   
      attestor_list   = ["projects/${var.project}/attestors/built-by-cloud-build"]
    },
    prod : {
      cluster_name    = "prod-binauthz"   
      attestor_list   = ["projects/${var.project}/attestors/built-by-cloud-build","${google_binary_authorization_attestor.attestor.id}"]
    }
  }
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

############################################
## Secure CI/CD Binary Authorization Demo ##
############################################

module "vpc" {
  source            = "../../modules/vpc"
  project           = var.project
  env               = local.env
  region            = var.region
  secondary_ranges  = {
    "${local.env}-subnet-01" = [
        {
            range_name      = "cluster-ipv4-cidr-block"
            ip_cidr_range   = "10.224.0.0/14"
        },
        {
            range_name      = "services-ipv4-cidr-block"
            ip_cidr_range   = "10.228.0.0/20"
        }
    ]
  }
}

module "gke_cluster" {
    count           = var.create_prod_gke_cluster ? 1 : 0
    source          = "../../modules/gke_cluster"
    cluster_name    = local.deployment_clusters[1].cluster_name
    project         = var.project
    region          = var.region
    network         = module.vpc.id
    subnetwork      = module.vpc.subnet
    master_ipv4_cidr= "10.${local.env == "dev" ? 10 : 20}.1.16/28"
}

# IAM Roles for the node pool service account
resource "google_project_iam_member" "compute_registry_reader" {
  count     = var.create_prod_gke_cluster ? 1 : 0
  project   = var.project
  role      = "roles/artifactregistry.reader"
  member    = "serviceAccount:${module.gke_cluster[0].service-account}"
}

resource "google_project_iam_member" "compute_deploy_jobrunner" {
  count     = var.create_prod_gke_cluster ? 1 : 0
  project   = var.project
  role      = "roles/clouddeploy.jobRunner"
  member    = "serviceAccount:${module.gke_cluster[0].service-account}"
}

resource "google_project_iam_member" "compute_container_admin" {
  count     = var.create_prod_gke_cluster ? 1 : 0
  project   = var.project
  role      = "roles/container.admin"
  member    = "serviceAccount:${module.gke_cluster[0].service-account}"
}

resource "google_pubsub_topic" "operations-pubsub" {
  name                          = "clouddeploy-operations"
  message_retention_duration    = "86400s"
}

resource "google_pubsub_topic" "approvals-pubsub" {
  name                          = "clouddeploy-approvals"
  message_retention_duration    = "86400s"
}

module "deploy-notification-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "deploy-notification"
    function-desc   = "triggered by operations-pubsub, communicates result of a deployment"
    entry-point     = "deploy_notification"
    triggers        = [
        {
            event_type  = "google.pubsub.topic.publish"
            resource    = google_pubsub_topic.operations-pubsub.id
        }
    ]
    env-vars        = {
        SLACK_DEVOPS_CHANNEL = var.slack_devops_channel
    }
    secrets         = [
        {
            key = "SLACK_ACCESS_TOKEN"
            id  = google_secret_manager_secret.slack-secure-cicd-bot-token.secret_id
        }
    ]
}

module "approval-notification-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "approval-notification"
    function-desc   = "triggered by approvals-pubsub, seeks approval for prod deployment"
    entry-point     = "approval_notification"
    triggers        = [
        {
            event_type  = "google.pubsub.topic.publish"
            resource    = google_pubsub_topic.approvals-pubsub.id
        }
    ]
    env-vars        = {
        SLACK_DEVOPS_CHANNEL = var.slack_devops_channel
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

# IAM entry for service accounts of deploy and approval notification functions to use the slack bot token
resource "google_secret_manager_secret_iam_binding" "cicd_bot_token_binding" {
  project   = google_secret_manager_secret.slack-secure-cicd-bot-token.project
  secret_id = google_secret_manager_secret.slack-secure-cicd-bot-token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.deploy-notification-cloud-function.sa-email}",
      "serviceAccount:${module.approval-notification-cloud-function.sa-email}",
  ]
}

module "deploy-approval-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "deploy-approval"
    function-desc   = "intakes approval decisions from slack for rollout a release to prod"
    entry-point     = "deploy_approval"
    env-vars        = {
        PROJECT_ID  = var.project
    }
    secrets         = [
        {
            key = "SLACK_SIGNING_SECRET"
            id  = google_secret_manager_secret.slack-secure-cicd-signing-secret.secret_id
        }
    ]
}

# IAM entry for all users to invoke the deploy-approval function
resource "google_cloudfunctions_function_iam_member" "deploy-approval-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.deploy-approval-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# IAM entry for service account of deploy-approval function to approve or reject rollouts
resource "google_project_iam_member" "deploy_approval_approver" {
  project   = var.project
  role      = "roles/clouddeploy.approver"
  member    = "serviceAccount:${module.deploy-approval-cloud-function.sa-email}"
}

resource "google_secret_manager_secret" "slack-secure-cicd-signing-secret" {
  project   = var.project
  secret_id = "slack-secure-cicd-signing-secret"

  replication {
    automatic = true
  }
}

# IAM entry for service account of deploy-approval function to use the slack signing secret
resource "google_secret_manager_secret_iam_binding" "cicd_signing_secret_binding" {
  project   = google_secret_manager_secret.slack-secure-cicd-signing-secret.project
  secret_id = google_secret_manager_secret.slack-secure-cicd-signing-secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.deploy-approval-cloud-function.sa-email}",
  ]
}

resource "google_clouddeploy_target" "deploy_target" {
  for_each          = local.deployment_clusters
  name              = each.value.cluster_name
  description       = "Target for ${each.key} environment"
  project           = var.project
  location          = var.region
  require_approval  = each.key == "prod" ? true : false

  gke {
    cluster = "projects/${var.project}/locations/${var.region}/clusters/${each.value.cluster_name}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy_execution_sa.email
  }

  depends_on = [
    google_project_iam_member.clouddeploy_service_agent_role
  ]
}
/*
resource "google_clouddeploy_target" "dev-cluster-target" {
  name              = "dev-cluster"
  description       = "Target for dev environment"
  project           = var.project
  location          = var.region
  require_approval  = false

  gke {
    cluster = "projects/${var.project}/locations/${var.region}/clusters/${var.dev_cluster_name}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy_execution_sa.email
  }

  depends_on = [
    google_project_iam_member.clouddeploy_service_agent_role
  ]
}

resource "google_clouddeploy_target" "prod-cluster-target" {
  count             = var.create_prod_gke_cluster ? 1 : 0
  name              = "prod-cluster"
  description       = "Target for prod environment"
  project           = var.project
  location          = var.region
  require_approval  = true

  gke {
    cluster = "projects/${var.project}/locations/${var.region}/clusters/${module.gke_cluster.name}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy_execution_sa.email
  }

  depends_on = [
    google_project_iam_member.clouddeploy_service_agent_role
  ]
}
*/
resource "google_clouddeploy_delivery_pipeline" "pipeline" {
  name        = "binauthz-demo-pipeline"
  description = "Pipeline for binauthz application" #TODO parameterize
  project     = var.project
  location    = var.region

  serial_pipeline {
    dynamic "stages" {
      for_each = local.deployment_clusters
      content {
        target_id = google_clouddeploy_target.deploy_target[stages.key].name
      }
    }
  }
}

# KMS resources
resource "google_kms_key_ring" "keyring" {
  name     = "${local.attestor_name}-keyring"
  location = "global"
}

resource "google_kms_crypto_key" "crypto-key" {
  name     = "${local.attestor_name}-key"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm           = "EC_SIGN_P256_SHA256"
    protection_level    = "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "google_kms_crypto_key_version" "version" {
  crypto_key = google_kms_crypto_key.crypto-key.id
}

resource "google_container_analysis_note" "note" {
  name = "${local.attestor_name}-note"
  attestation_authority {
    hint {
      human_readable_name = "My Binary Authorization Demo!"
    }
  }
}

resource "google_binary_authorization_attestor" "attestor" {
  name = "${local.attestor_name}"
  attestation_authority_note {
    note_reference = google_container_analysis_note.note.name
    public_keys {
      id = data.google_kms_crypto_key_version.version.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.version.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.version.public_key[0].algorithm
      }
    }
  }
}

# Binary Authorization Policy for the dev and prod gke_clusters
resource "google_binary_authorization_policy" "prod_binauthz_policy" {
  project = var.project
  
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google_containers/*"
  }

  default_admission_rule {
    evaluation_mode  = "ALWAYS_ALLOW"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }

  admission_whitelist_patterns {
    name_pattern = "docker.io/library/mysql:latest"
  }

  admission_whitelist_patterns {
    name_pattern = "docker.io/bkimminich/juice-shop:latest"
  }
  
  dynamic "cluster_admission_rules" {
    for_each    = local.deployment_clusters
    content {
      cluster                 = "${var.region}.${each.value.cluster_name}"
      evaluation_mode         = "REQUIRE_ATTESTATION"
      enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
      require_attestations_by = each.value.attestor_list
    }
  }

  /*
  cluster_admission_rules {
    cluster                 = "${var.region}.${var.dev_cluster_name}"
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = ["projects/${var.project}/attestors/built-by-cloud-build"]
  }

  #cluster_admission_rules {
  #  cluster                 = "${var.region}.${module.gke_cluster.name}"
  #  evaluation_mode         = "REQUIRE_ATTESTATION"
  #  enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  #  require_attestations_by = ["projects/${var.project}/attestors/built-by-cloud-build","${google_binary_authorization_attestor.attestor.id}"]
  #}
  */
}

###########################################
## JIT Privileged Access Management Demo ##
###########################################

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
resource "google_organization_iam_member" "provision_access_org_iam_admin" {
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

#####################################
## Cloud DLP API Storage Scan Demo ##
#####################################

# GCS bucket to store raw files to be scanned by DLP
resource "google_storage_bucket" "raw_bucket" {
  name                          = "${var.project}-raw-bucket"
  location                      = var.region
  uniform_bucket_level_access   = true
}

# GCS bucket to store redacted files scanned by DLP
resource "google_storage_bucket" "redacted_bucket" {
  name                          = "${var.project}-redacted-bucket"
  location                      = var.region
  uniform_bucket_level_access   = true
}

module "dlp-scan-storage-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "dlp-scan-storage"
    function-desc   = "scans new files in a bucket and stores redacted versions in another bucket"
    entry-point     = "dlp_scan_storage"
    env-vars        = {
        PROJECT_NAME            = var.project,
        REDACTED_BUCKET_NAME    = google_storage_bucket.redacted_bucket.name
    }
    triggers        = [
        {
            event_type  = "google.storage.object.finalize"
            resource    = google_storage_bucket.raw_bucket.name
        }
    ]
}

# Create a custom IAM role for the dlp-scan-storage function over storage buckets
resource "google_project_iam_custom_role" "dlp-scan-storage-custom-role" {
  role_id     = "dlp_scan_storage_custom_role"
  title       = "Custom Role for the dlp-scan-storage function to read/write from storage buckets"
  description = "This role is used by the dlp-scan-storage function's SA in ${var.project}"
  permissions = ["storage.buckets.get","storage.objects.create","storage.objects.delete","storage.objects.get"]
}

# IAM entry for service account of dlp-scan-storage function over raw bucket
resource "google_storage_bucket_iam_member" "raw_bucket_read" {
  bucket = google_storage_bucket.raw_bucket.name
  role = google_project_iam_custom_role.dlp-scan-storage-custom-role.name
  member = "serviceAccount:${module.dlp-scan-storage-cloud-function.sa-email}"
}

# IAM entry for service account of dlp-scan-storage function over redacted bucket
resource "google_storage_bucket_iam_member" "redacted_bucket_write" {
  bucket = google_storage_bucket.redacted_bucket.name
  role = google_project_iam_custom_role.dlp-scan-storage-custom-role.name
  member = "serviceAccount:${module.dlp-scan-storage-cloud-function.sa-email}"
}

# IAM entry for service account of dlp-scan-storage function to use the DLP service
resource "google_project_iam_member" "project_dlp_user_storage" {
  project = var.project
  role    = "roles/dlp.user"
  member  = "serviceAccount:${module.dlp-scan-storage-cloud-function.sa-email}"
}

###################################
## Cloud DLP BQ Remote Scan Demo ##
###################################

# BQ dataset to store raw files to be scanned by DLP
resource "google_bigquery_dataset" "dlp_scan_dataset" {
  dataset_id                  = "dlp_scan_dataset"
  description                 = "demo of dlp scan using bq remote functions"
  location                    = var.region
  default_table_expiration_ms = 3600000
}

module "dlp-scan-bq-remote-cloud-function" {
  source            = "../../modules/cloud_function"
  project           = var.project
  function-name     = "dlp-scan-bq-remote"
  function-desc     = "scans data provided in bq queries and returns redacted values"
  entry-point       = "dlp_scan_bq_remote"
  env-vars          = {
      PROJECT_NAME  = var.project
      WRAPPED_KEY   = var.dlp_wrapped_key
      KMS_KEY       = google_kms_crypto_key.dlp_tokenize_key.id
    }
}

# This creates a cloud resource connection.
# The cloud resource nested object has only one output only field - serviceAccountId.
resource "google_bigquery_connection" "connection" {
  connection_id   = "dlp-scan-bq-remote-connection"
  project         = var.project
  location        = var.region
  cloud_resource {}
}

# IAM entry for service account of the connection created in the last step to invoke the dlp-scan-bq-remote function
resource "google_cloudfunctions_function_iam_member" "dlp-scan-bq-remote-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.dlp-scan-bq-remote-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = format("serviceAccount:%s", google_bigquery_connection.connection.cloud_resource[0].service_account_id)
}

# IAM entry for service account of dlp-scan-bq-remote function to use the DLP service
resource "google_project_iam_member" "project_dlp_user_bq_remote" {
  project = var.project
  role    = "roles/dlp.user"
  member  = "serviceAccount:${module.dlp-scan-bq-remote-cloud-function.sa-email}"
}

# KMS resources
resource "google_kms_key_ring" "dlp_tokenize_keyring" {
  name     = "dlp-tokenize-keyring"
  location = "global"
}

resource "google_kms_crypto_key" "dlp_tokenize_key" {
  name     = "dlp-tokenize-key"
  key_ring = google_kms_key_ring.dlp_tokenize_keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  version_template {
    algorithm           = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level    = "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "google_kms_crypto_key_version" "dlp_tokenize_key_version" {
  crypto_key = google_kms_crypto_key.dlp_tokenize_key.id
}



###############################
## reCAPTCHA Enterprise Demo ##
###############################

resource "google_recaptcha_enterprise_key" "www-site-score-key" {
  display_name = "www-site-score-key"
  project = var.demo_project

  web_settings {
    integration_type  = "SCORE"
    allow_all_domains = false
    allow_amp_traffic = false
    allowed_domains   = ["www.agarsand.demo.altostrat.com"]
  }
}

module "recaptcha-backend-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "recaptcha-backend"
    function-desc   = "processes login requests from the serverless webpage securely using recaptcha enterprise"
    entry-point     = "recaptcha_website"
    env-vars        = {
        PROJECT_ID          = var.demo_project,
        USERNAME            = var.website_username
    }
    secrets         = [
        {
            key = "RECAPTCHA_SITE_KEY"
            id  = google_secret_manager_secret.recaptcha-site-key.secret_id
        },
        {
            key = "PASSWORD"
            id  = google_secret_manager_secret.recaptcha-website-password.secret_id
        }
    ]
}

# IAM entry for all users to invoke the recaptcha-backend function
resource "google_cloudfunctions_function_iam_member" "recaptcha-backend-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.recaptcha-backend-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# IAM entry for service account of recaptcha-backend function to use the reCAPTCHA service
resource "google_project_iam_member" "project_recaptcha_user" {
  project = var.demo_project
  role    = "roles/recaptchaenterprise.agent"
  member  = "serviceAccount:${module.recaptcha-backend-cloud-function.sa-email}"
}

resource "google_secret_manager_secret" "recaptcha-site-key" {
  project   = var.project
  secret_id = "recaptcha-site-key"

  replication {
    automatic = true
  }
}

# IAM entry for service account of recaptcha-backend function to use the recaptcha site key
resource "google_secret_manager_secret_iam_binding" "recaptcha_sitekey_binding" {
  project   = google_secret_manager_secret.recaptcha-site-key.project
  secret_id = google_secret_manager_secret.recaptcha-site-key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.recaptcha-backend-cloud-function.sa-email}",
  ]
}

resource "google_secret_manager_secret" "recaptcha-website-password" {
  project   = var.project
  secret_id = "recaptcha-website-password"

  replication {
    automatic = true
  }
}

# IAM entry for service account of recaptcha-backend function to use the recaptcha website password
resource "google_secret_manager_secret_iam_binding" "website_password_binding" {
  project   = google_secret_manager_secret.recaptcha-website-password.project
  secret_id = google_secret_manager_secret.recaptcha-website-password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.recaptcha-backend-cloud-function.sa-email}",
  ]
}

#####################################################
## SCC Automatic Notification and Remediation Demo ##
#####################################################

resource "google_pubsub_topic" "scc-slack-notification-topic" {
  name = "scc-slack-notification-topic"
  message_retention_duration = "86400s"
}

resource "google_scc_notification_config" "scc-slack-notification-config" {
  config_id    = "scc-slack-notification-config"
  organization = var.organization
  description  = "My SCC Finding Notification Configuration for SLACK"
  pubsub_topic =  google_pubsub_topic.scc-slack-notification-topic.id

  streaming_config {
    filter = "state = \"ACTIVE\" AND mute != \"MUTED\""
  }
}

module "scc-slack-notification-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "scc-slack-notification"
    function-desc   = "triggered by scc-notifications-topic, communicates findings reported by scc"
    entry-point     = "scc_slack_notification"
    env-vars        = {
        SLACK_CHANNEL = var.slack_secops_channel,
    }
    secrets         = [
        {
            key = "SLACK_ACCESS_TOKEN"
            id  = google_secret_manager_secret.slack-scc-bot-token.secret_id
        }
    ]
    triggers        = [
        {
            event_type  = "google.pubsub.topic.publish"
            resource    = google_pubsub_topic.scc-slack-notification-topic.id
        }
    ]
}

resource "google_secret_manager_secret" "slack-scc-bot-token" {
  project   = var.project
  secret_id = "slack-scc-bot-token"

  replication {
    automatic = true
  }
}

# IAM entry for service account of scc-slack-notification function to use the slack bot token
resource "google_secret_manager_secret_iam_binding" "scc_bot_token_binding" {
  project   = google_secret_manager_secret.slack-scc-bot-token.project
  secret_id = google_secret_manager_secret.slack-scc-bot-token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.scc-slack-notification-cloud-function.sa-email}",
  ]
}

module "scc-remediation-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "scc-remediation"
    function-desc   = "intakes requests from slack for responses to scc findings"
    entry-point     = "scc_remediation"
    secrets         = [
        {
            key = "SLACK_SIGNING_SECRET"
            id  = google_secret_manager_secret.slack-scc-signing-secret.secret_id
        }
    ]
}

# IAM entry for all users to invoke the scc-remediation function
resource "google_cloudfunctions_function_iam_member" "scc-remediation-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.scc-remediation-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "google_secret_manager_secret" "slack-scc-signing-secret" {
  project   = var.project
  secret_id = "slack-scc-signing-secret"

  replication {
    automatic = true
  }
}

# IAM entry for service account of scc-remediation function to use the slack signing secret
resource "google_secret_manager_secret_iam_binding" "scc_signing_secret_binding" {
  project   = google_secret_manager_secret.slack-scc-signing-secret.project
  secret_id = google_secret_manager_secret.slack-scc-signing-secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.scc-remediation-cloud-function.sa-email}",
  ]
}

module "mute-finding-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "mute-finding"
    function-desc   = "mutes scc findings"
    entry-point     = "mute_finding"
}

# IAM entry for service account of scc-remediation function to invoke the mute-finding function
resource "google_cloudfunctions_function_iam_member" "mute-finding-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.mute-finding-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${module.scc-remediation-cloud-function.sa-email}"
}

# IAM entry for service account of mute-finding function to mute SCC findings
resource "google_organization_iam_member" "mute_finding_org_role" {
  org_id    = var.organization
  role      = "roles/securitycenter.findingsMuteSetter"
  member    = "serviceAccount:${module.mute-finding-cloud-function.sa-email}"
}

module "deactivate-finding-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "deactivate-finding"
    function-desc   = "deactivates scc findings"
    entry-point     = "deactivate_finding"
}

# IAM entry for service account of scc-remediation function to invoke the deactivate-finding function
resource "google_cloudfunctions_function_iam_member" "deactivate-finding-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.deactivate-finding-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${module.scc-remediation-cloud-function.sa-email}"
}

# IAM entry for service account of deactivate-finding function to deactivate SCC findings
resource "google_organization_iam_member" "deactivate_finding_org_role" {
  org_id    = var.organization
  role      = "roles/securitycenter.findingsStateSetter"
  member    = "serviceAccount:${module.deactivate-finding-cloud-function.sa-email}"
}

# Create a custom IAM role for the scc-remediation function over the entire org
resource "google_organization_iam_custom_role" "scc-remediation-custom-role" {
  role_id     = "scc_remediation_custom_role"
  org_id      = var.organization
  title       = "Custom Role for SCC Remediation Cloud Functions"
  description = "This role is used by various remediate-* function SAs to remediate SCC findings"
  permissions = ["compute.firewalls.delete","compute.instances.delete","compute.networks.updatePolicy","compute.globalOperations.get","compute.zoneOperations.get","storage.buckets.getIamPolicy","storage.buckets.setIamPolicy"]
}

module "remediate-firewall-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "remediate-firewall"
    function-desc   = "remediates scc findings related to misconfigured firewalls"
    entry-point     = "remediate_firewall"
}

# IAM entry for service account of scc-remediation function to invoke the remediate-firewall function
resource "google_cloudfunctions_function_iam_member" "remediate-firewall-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.remediate-firewall-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${module.scc-remediation-cloud-function.sa-email}"
}

# IAM entry for service account of remediate-firewall function
resource "google_organization_iam_member" "remediate_firewall_org_scc_remediation" {
  org_id    = var.organization
  role      = google_organization_iam_custom_role.scc-remediation-custom-role.name
  member    = "serviceAccount:${module.remediate-firewall-cloud-function.sa-email}"
}

module "remediate-instance-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "remediate-instance"
    function-desc   = "remediates scc findings related to misconfigured instances"
    entry-point     = "remediate_instance"
}

# IAM entry for service account of scc-remediation function to invoke the remediate-instance function
resource "google_cloudfunctions_function_iam_member" "remediate-instance-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.remediate-instance-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${module.scc-remediation-cloud-function.sa-email}"
}

# IAM entry for service account of remediate-instance function
resource "google_organization_iam_member" "remediate_instance_org_scc_remediation" {
  org_id    = var.organization
  role      = google_organization_iam_custom_role.scc-remediation-custom-role.name
  member    = "serviceAccount:${module.remediate-instance-cloud-function.sa-email}"
}

module "remediate-bucket-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "remediate-bucket"
    function-desc   = "remediates scc findings related to misconfigured buckets"
    entry-point     = "remediate_bucket"
}

# IAM entry for service account of scc-remediation function to invoke the remediate-bucket function
resource "google_cloudfunctions_function_iam_member" "remediate-bucket-invoker" {
  project        = var.project
  region         = var.region
  cloud_function = module.remediate-bucket-cloud-function.function_name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${module.scc-remediation-cloud-function.sa-email}"
}

# IAM entry for service account of remediate-bucket function
resource "google_organization_iam_member" "remediate_bucket_org_scc_remediation" {
  org_id    = var.organization
  role      = google_organization_iam_custom_role.scc-remediation-custom-role.name
  member    = "serviceAccount:${module.remediate-bucket-cloud-function.sa-email}"
}

##########################################
## SCC JIRA Automatic Notification Demo ##
##########################################

resource "google_pubsub_topic" "scc-jira-notification-topic" {
  name = "scc-jira-notification-topic"
  message_retention_duration = "86400s"
}

resource "google_scc_notification_config" "scc-jira-notification-config" {
  config_id    = "scc-jira-notification-config"
  organization = var.organization
  description  = "My SCC Finding Notification Configuration for JIRA"
  pubsub_topic =  google_pubsub_topic.scc-jira-notification-topic.id

  streaming_config {
    filter = "mute != \"MUTED\""
  }
}

module "scc-jira-notification-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "scc-jira-notification"
    function-desc   = "triggered by scc-jira-notification-topic, communicates scc findings to jira board"
    entry-point     = "process_notification"
    env-vars        = {
        USER_ID             =   var.atlassian_email,
        DOMAIN              =   var.atlassian_domain,
        JIRA_PROJECT_KEY    =   var.jira_project_key,
        ISSUE_TYPE          =   "Task",
        STATUS_OPEN         =   "To Do",
        STATUS_WIP          =   "In Progress",
        STATUS_DONE         =   "Done",
    }
    secrets         = [
        {
            key = "ATLASSIAN_API_TOKEN"
            id  = google_secret_manager_secret.atlassian-api-token.secret_id
        }
    ]
    triggers        = [
        {
            event_type  = "google.pubsub.topic.publish"
            resource    = google_pubsub_topic.scc-jira-notification-topic.id
        }
    ]
}

resource "google_secret_manager_secret" "atlassian-api-token" {
  project   = var.project
  secret_id = "atlassian-api-token"

  replication {
    automatic = true
  }
}

# IAM entry for service account of scc-jira-notification function to use the atlassian api token
resource "google_secret_manager_secret_iam_binding" "atlassian_api_token_binding" {
  project   = google_secret_manager_secret.atlassian-api-token.project
  secret_id = google_secret_manager_secret.atlassian-api-token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.scc-jira-notification-cloud-function.sa-email}",
  ]
}

resource "google_app_engine_application" "app" {
  project       = var.project
  location_id   = "us-central"
  database_type = "CLOUD_FIRESTORE"
}

# IAM entry for service account of scc-jira-notification function to use the Firestore database
resource "google_project_iam_member" "project" {
  project = var.project
  role    = "roles/datastore.user"
  member  = "serviceAccount:${module.scc-jira-notification-cloud-function.sa-email}"
}

######################################
## Admin Login Alerts to Slack Demo ##
######################################

resource "google_logging_organization_sink" "cloud_identity_logs_sink" {
  org_id        = var.organization
  name          = "cloud-identity-logs-sink"
  description   = "writes high-risk event logs from cloud identity to pub/sub"
  
  destination   = "pubsub.googleapis.com/${google_pubsub_topic.identity_notification_topic.id}"

  # Report all activity logs relating to the admin console
  filter        = "protoPayload.serviceName=\"admin.googleapis.com\""
}

resource "google_pubsub_topic_iam_member" "cloud_identity_logs_writer" {
  project   = google_pubsub_topic.identity_notification_topic.project
  topic     = google_pubsub_topic.identity_notification_topic.name
  role      = "roles/pubsub.publisher"
  member    = google_logging_organization_sink.cloud_identity_logs_sink.writer_identity
}

resource "google_pubsub_topic" "identity_notification_topic" {
  name = "identity-notification-topic"
  message_retention_duration = "86400s"
}

module "identity-notification-cloud-function" {
    source          = "../../modules/cloud_function"
    project         = var.project
    function-name   = "identity-notification"
    function-desc   = "triggered by identity-notification-topic, communicates admin console activities"
    entry-point     = "identity_notification"
    env-vars        = {
        SLACK_CHANNEL = var.slack_secops_channel,
    }
    secrets         = [
        {
            key = "SLACK_ACCESS_TOKEN"
            id  = google_secret_manager_secret.slack_identity_bot_token.secret_id
        }
    ]
    triggers        = [
        {
            event_type  = "google.pubsub.topic.publish"
            resource    = google_pubsub_topic.identity_notification_topic.id
        }
    ]
}

resource "google_secret_manager_secret" "slack_identity_bot_token" {
  project   = var.project
  secret_id = "slack-identity-bot-token"

  replication {
    automatic = true
  }
}

# IAM entry for service account of identity-notification function to use the slack bot token
resource "google_secret_manager_secret_iam_binding" "identity_bot_token_binding" {
  project   = google_secret_manager_secret.slack_identity_bot_token.project
  secret_id = google_secret_manager_secret.slack_identity_bot_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${module.identity-notification-cloud-function.sa-email}",
  ]
}