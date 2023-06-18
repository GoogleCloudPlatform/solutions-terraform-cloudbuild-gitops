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

resource "google_compute_global_address" "lb_ip_address" {
  name          = "dev-lb-static-ip"
  project       = var.project
}
/*
resource "google_recaptcha_enterprise_key" "recaptcha_test_site_key" {
  provider      = google-beta
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
  provider      = google-beta
  display_name  = "recaptcha-redirect-site-key"
  project       = var.demo_project

  web_settings {
    integration_type              = "INVISIBLE"
    allow_all_domains             = false
    allowed_domains               = ["agarsand.demo.altostrat.com"]
    challenge_security_preference = "USABILITY"
  }
}

# Cloud Armor WAF Policy for Dev Backends
resource "google_compute_security_policy" "gke_waf_security_policy" {
  provider      = google-beta
  name          = "gke-waf-security-policy"
  description   = "Cloud Armor Security Policy"
  project       = var.project
  type          = "CLOUD_ARMOR"

  recaptcha_options_config {
    redirect_site_key = "6LcGeukhAAAAAAfjGfl0YIEtMEoUIy2uq_QjhJBQ"
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
    priority = "3000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable', ['owasp-crs-v030001-id942251-sqli', 'owasp-crs-v030001-id942420-sqli', 'owasp-crs-v030001-id942431-sqli', 'owasp-crs-v030001-id942460-sqli', 'owasp-crs-v030001-id942421-sqli', 'owasp-crs-v030001-id942432-sqli'])"
      }
    }
    description = "Allow only Indians. Mera Bharat Mahan! :)"
  }

  rule {
    action   = "deny(403)"
    priority = "6000"
    match {
      expr {
        expression = "origin.region_code != 'IN'"
      }
    }
    description = "Allow only users from India. Mera Bharat Mahan! :)"
  }

  rule {
    action   = "redirect"
    priority = "7000"
    
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["104.132.232.68/32"]
      }
    }

    redirect_options {
        type = "EXTERNAL_302"
        target = "https://www.agarsand.demo.altostrat.com/denied.html"
    }

    description = "Deny access to IPs"
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
    description = "Redirect to challenge page if the recaptcha session score is between thresholds"
  }

  rule {
    action   = "throttle"
    priority = "11000"
    match {
      expr {
        expression = "request.headers['host'].lower().contains('gke.agarsand.demo.altostrat.com')"
      }
    }
    rate_limit_options {
        conform_action  = "allow"
        exceed_action   = "deny(429)"

        enforce_on_key  = "ALL"

        rate_limit_threshold {
            count           = 5
            interval_sec    = 60
        }
    }
    description = "Rate-based Throttle"
  }

  rule {
    action      = "rate_based_ban"
    priority    = "12000"
    match {
      expr {
        expression = "request.headers['host'].lower().matches('owasp.agarsand.demo.altostrat.com')"
      }
    }
    rate_limit_options {
        conform_action  = "allow"
        exceed_action   = "deny(429)"

        enforce_on_key  = "ALL"

        rate_limit_threshold {
            count           = 10
            interval_sec    = 60
        }

        ban_duration_sec    = 300
    }
    description = "Rate-based Throttle"
    preview     = true
  }
}
*/
############################
## Website Storage Bucket ##
############################

resource "google_storage_bucket" "www" {
 project       = var.project
 name          = "www.agarsand.demo.altostrat.com"
 location      = "US"
 storage_class = "STANDARD"

 uniform_bucket_level_access = true

 website {
    main_page_suffix = "index.html"
    not_found_page   = "denied.html"
  }
}

# IAM entry for the bucket to make it publicly readable
resource "google_storage_bucket_iam_member" "member" {
  bucket    = google_storage_bucket.www.id
  role      = "roles/storage.objectViewer"
  member    = "allUsers"
} 

# Upload html and image files as objects to the bucket
resource "google_storage_bucket_object" "index_html" {
 name         = "index.html"
 source       = "../../www/index.html"
 content_type = "text/html"
 bucket       = google_storage_bucket.www.id
}

resource "google_storage_bucket_object" "denied_html" {
 name         = "denied.html"
 source       = "../../www/denied.html"
 content_type = "text/html"
 bucket       = google_storage_bucket.www.id
}

resource "google_storage_bucket_object" "denied_png" {
 name         = "denied.png"
 source       = "../../www/denied.png"
 content_type = "image/jpeg"
 bucket       = google_storage_bucket.www.id
}

##############################
## Pulumi Related Resources ##
##############################

resource "google_secret_manager_secret" "pulumi_access_token" {
  project   = var.project
  secret_id = "pulumi-access-token"

  replication {
    automatic = true
  }
}

####################################
## IAP, Cloud Run, Cloud SQL Demo ##
####################################

# reserved IP address
resource "google_compute_global_address" "iap_run_sql_demo" {
  name          = "iap-run-sql-demo"
  project       = var.project
}

resource "google_compute_managed_ssl_certificate" "iap_run_sql_demo" {
  name = "iap-run-sql-demo-cert"

  managed {
    domains = ["run.agarsand.demo.altostrat.com."]
  }
}

# forwarding rule
resource "google_compute_global_forwarding_rule" "https" {
  project               = var.project
  name                  = "iap-run-sql-demo-https-fw-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.iap_run_sql_demo.id
  ip_address            = google_compute_global_address.iap_run_sql_demo.id
}

# http proxy
resource "google_compute_target_https_proxy" "iap_run_sql_demo" {
  name        = "iap-run-sql-demo"
  url_map     = google_compute_url_map.iap_run_sql_demo.id
  ssl_certificates = [google_compute_managed_ssl_certificate.iap_run_sql_demo.id]
}

# url map
resource "google_compute_url_map" "iap_run_sql_demo" {
  name            = "iap-run-sql-demo-url-map"
  description     = "a description"
  default_service = google_compute_backend_service.iap_run_sql_demo_backend.id

  host_rule {
    hosts        = ["run.agarsand.demo.altostrat.com"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.iap_run_sql_demo_backend.id

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_service.iap_run_sql_demo_backend.id
    }
  }
}

# backend service
resource "google_compute_backend_service" "iap_run_sql_demo_backend" {
  project               = var.project            
  name                  = "iap-run-sql-demo-serverless-backend"
  port_name             = "http"
  protocol              = "HTTP"
  enable_cdn            = false

  backend {
    group                   = google_compute_region_network_endpoint_group.iap_run_sql_demo_neg.id
  }

  log_config {
    enable              = false
  }

  #iap {
  #  oauth2_client_id     = null
  #  oauth2_client_secret = null
  #}
}

# network endpoint group
resource "google_compute_region_network_endpoint_group" "iap_run_sql_demo_neg" {
  name                  = "iap-run-sql-demo-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.iap_run_service.name
  }
}

# Create the Cloud Run service
resource "google_cloud_run_service" "iap_run_service" {
  name      = "iap-run-sql-demo"
  location  = var.region

  template {
    spec {
      containers {
        image = "gcr.io/google-samples/hello-app:1.0"
      }
    }
  }

  metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "2"
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.iap_run_sql_demo_db_instance.connection_name
        "run.googleapis.com/client-name"        = "terraform"
      }
    }

  traffic {
    percent         = 100
    latest_revision = true
  }

  lifecycle {
    ignore_changes = [
      metadata.0.annotations,
    ]
  }
}

# Allow unauthenticated users to invoke the service
resource "google_cloud_run_service_iam_member" "run_all_users" {
  service  = google_cloud_run_service.iap_run_service.name
  location = google_cloud_run_service.iap_run_service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_sql_database" "iap_run_sql_demo_database" {
  name     = "iap-run-sql-demo-db"
  instance = google_sql_database_instance.iap_run_sql_demo_db_instance.name
}

resource "google_sql_database_instance" "iap_run_sql_demo_db_instance" {
  name             = "iap-run-sql-demo-db-instance"
  region           = var.region
  database_version = "POSTGRES_14"
  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled  = true
      require_ssl   = true

      dynamic "authorized_networks" {
        for_each    = var.onprem_ips
        iterator    = onprem_ip

        content {
          name      = "onprem_ip-${onprem_ip.key}"
          value     = onprem_ip.value
        }
      }
    }
  }

  deletion_protection  = "false"
}

resource "google_sql_user" "db_user" {
  name     = "pensande@agarsand.altostrat.com"
  instance = google_sql_database_instance.iap_run_sql_demo_db_instance.name
  type     = "CLOUD_IAM_USER"
}

resource "google_project_iam_member" "user" {  
  project = var.project
  role   = "roles/cloudsql.instanceUser"
  member  = "user:pensande@agarsand.altostrat.com"
 

resource "google_project_iam_member" "client" {  
  project = var.project
  role   = "roles/cloudsql.client"
  member  = "user:pensande@agarsand.altostrat.com"
}
