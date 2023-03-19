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
  project = "${var.project}"
}

provider "google-beta" {
  project   = var.project
  region    = var.region
}

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

module "cloud_nat" {
  source  = "../../modules/cloud_nat"
  project = var.project
  network = module.vpc.name
  region  = var.region
}
/*
module "gke_cluster" {
    source          = "../../modules/gke_cluster"
    cluster_name    = "${local.env}-binauthz"
    project         = var.project
    region          = var.region
    network         = module.vpc.id
    subnetwork      = module.vpc.subnet
    master_ipv4_cidr= "10.${local.env == "dev" ? 10 : 20}.1.16/28"
}

# IAM Roles for the node pool service account
resource "google_project_iam_member" "compute_registry_reader" {
  project  = var.project
  role     = "roles/artifactregistry.reader"
  member   = "serviceAccount:${module.gke_cluster.service-account}"
}

resource "google_project_iam_member" "compute_deploy_jobrunner" {
  project  = var.project
  role     = "roles/clouddeploy.jobRunner"
  member   = "serviceAccount:${module.gke_cluster.service-account}"
}

resource "google_project_iam_member" "compute_container_admin" {
  project  = var.project
  role     = "roles/container.admin"
  member   = "serviceAccount:${module.gke_cluster.service-account}"
}
*/
# Workload Identity for the Kubernetes Cluster
resource "google_service_account" "k8s_app_service_account" {
  account_id   = "sa-k8s-app"
  display_name = "Service Account For Workload Identity"
}

# IAM entry for k8s service account to use the service account of workload identity
resource "google_service_account_iam_member" "workload_identity-role" {
  service_account_id = google_service_account.k8s_app_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project}.svc.id.goog[default/my-k8s-app]"
}

resource "google_secret_manager_secret" "mysql-root-password" {
  project   = var.project
  secret_id = "mysql-root-password"

  replication {
    automatic = true
  }
}

# IAM entry for service account of workload identity to use the mysql-root-password secret
resource "google_secret_manager_secret_iam_binding" "mysql_root_password_secret_binding" {
  project   = google_secret_manager_secret.mysql-root-password.project
  secret_id = google_secret_manager_secret.mysql-root-password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members    = [
      "serviceAccount:${google_service_account.k8s_app_service_account.email}",
  ]
}

# Artifact Registry repo for binauthz-demo
resource "google_artifact_registry_repository" "binauthz-demo-repo" {
  provider      = google-beta
  project       = var.project

  location      = var.region
  repository_id = "binauthz-demo-repo"
  description   = "Docker repository for binauthz demo"
  format        = "DOCKER"
}

resource "google_compute_address" "lb_ip_address" {
  name          = "dev-lb-static-ip"
  project       = var.project
  region        = var.region 
  address_type  = "EXTERNAL"
  description   = "static ip address for the dev loadbalancer"
}

resource "google_recaptcha_enterprise_key" "recaptcha_test_site_key" {
  display_name  = "recaptcha-test-site-key"
  project       = var.demo_project

  testing_options {
    testing_score = 0.5
  }

  web_settings {
    integration_type  = "SCORE"
    allow_all_domains = false
    allow_amp_traffic = false
    allowed_domains   = ["agarsand.demo.altostrat.com"]
  }
}

resource "google_recaptcha_enterprise_key" "recaptcha_redirect_site_key" {
  display_name  = "recaptcha-redirect-site-key"
  project       = var.demo_project

  web_settings {
    integration_type              = "INVISIBLE"
    allow_all_domains             = false
    allowed_domains               = [agarsand.demo.altostrat.com]
    challenge_security_preference = "USABILITY"
  }
}

# Cloud Armor WAF Policy for Dev Backends
resource "google_compute_security_policy" "policy" {
  project_id                           = var.project
  name                                 = "dev-waf-security-policy"
  description                          = "Cloud Armor Security Policy"
  type        = "CLOUD_ARMOR"

  recaptcha_options_config {
    redirect_site_key = google_recaptcha_enterprise_key.recaptcha_redirect_site_key.name
  }

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule"
  }

  rule {
    action   = "deny(403)"
    priority = "7000"
    match {
      expr {
        expression = "origin.region_code != 'IN'"
      }
    }
    description = "Allow only Indians. Mera Bharat Mahan! :)"
  }

  rule {
    action   = "allow"
    priority = "8000"
    match {
      expr {
        expression = "request.path.matches('good-score.html') && token.recaptcha_session.score > 0.4"
      }
    }
    description = "Allow if the recaptcha session score is above threshold"
  }

  rule {
    action   = "deny(403)"
    priority = "9000"
    match {
      expr {
        expression = "request.path.matches('bad-score.html') && token.recaptcha_session.score < 0.6"
      }
    }
    description = "Deny if the recaptcha session score is below threshold"
  }

  rule {
    action   = "redirect"
    priority = "10000"
    match {
      expr {
        expression = "request.path.matches('median-score.html') && token.recaptcha_session.score == 0.5"
      }
    }
    redirect_options {
      type = "GOOGLE_RECAPTCHA"
    }
    description = "Redirect if the recaptcha session score is between thresholds"
  }
}