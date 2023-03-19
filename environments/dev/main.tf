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
module "security_policy" {
  source = "GoogleCloudPlatform/cloud-armor/google"
  version = "~> 0.2"

  project_id                           = var.project
  name                                 = "dev-waf-security-policy"
  description                          = "Cloud Armor Security Policy"
  recaptcha_redirect_site_key          = google_recaptcha_enterprise_key.recaptcha_redirect_site_key.name
  default_rule_action                  = "allow"
  type                                 = "CLOUD_ARMOR"

  pre_configured_rules = {
    "sqli_sensitivity_level_4_with_exclude" = {
      action                    = "deny(403)"
      priority                  = 3000
      target_rule_set           = "sqli-stable"
      exclude_target_rule_ids   = ["owasp-crs-v030001-id942251-sqli", "owasp-crs-v030001-id942420-sqli", "owasp-crs-v030001-id942431-sqli", "owasp-crs-v030001-id942460-sqli", "owasp-crs-v030001-id942421-sqli", "owasp-crs-v030001-id942432-sqli"]
    }
  }

  custom_rules = {

    deny_specific_regions = {
      action      = "deny(403)"
      priority    = 7000
      description = "Allow only Indians. Mera Bharat Mahan! :)"
      expression  = <<-EOT
        origin.region_code != 'IN'
      EOT
    }

    allow_good_scores = {
      action      = "allow"
      priority    = 8000
      description = "Allow if the recaptcha session score is above threshold"
      expression  = <<-EOT
        request.path.matches('good-score.html') && token.recaptcha_session.score > 0.4
      EOT
    }

    deny_bad_scores = {
      action      = "deny(403)"
      priority    = 9000
      description = "Deny if the recaptcha session score is below threshold"
      expression  = <<-EOT
        request.path.matches('bad-score.html') && token.recaptcha_session.score < 0.6
      EOT
    }

    redirect_median_scores = {
      action        = "redirect"
      priority      = 10000
      description   = "Redirect if the recaptcha session score is between thresholds"
      expression    = <<-EOT
        request.path.matches('median-score.html') && token.recaptcha_session.score == 0.5
      EOT
      redirect_type = "GOOGLE_RECAPTCHA"
    }

    throttle_specific_ip_region = {
      action      = "throttle"
      priority    = 11000
      description = "Throttle traffic to recaptcha demo application"
      expression  = <<-EOT
        request.headers['host'].lower().contains('agarsand.demo.altostrat.com') && !request.headers['host'].lower().matches('owasp.agarsand.demo.altostrat.com')
      EOT
      rate_limit_options = {
        exceed_action                        = "deny(429)"
        rate_limit_http_request_count        = 5
        rate_limit_http_request_interval_sec = 60
        enforce_on_key                       = "ALL"
      }
    }

    rate_ban_specific_ip = {
      action     = "rate_based_ban"
      priority   = 12000
      description = "Ban traffic to owasp demo application"
      preview     = true
      expression = <<-EOT
        request.headers['host'].lower().matches('owasp.agarsand.demo.altostrat.com')
      EOT
      rate_limit_options = {
        exceed_action                        = "deny(502)"
        rate_limit_http_request_count        = 10
        rate_limit_http_request_interval_sec = 60
        ban_duration_sec                     = 120
        ban_http_request_count               = 10
        ban_http_request_interval_sec        = 60
        enforce_on_key                       = "ALL"
      }
    }

  }

}