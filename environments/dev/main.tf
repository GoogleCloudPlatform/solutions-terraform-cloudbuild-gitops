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

resource "google_compute_network" "vpc" {
  name                    = "${local.env}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name                      = "${local.env}-subnet-01"
  ip_cidr_range             = "10.${local.env == "dev" ? 10 : 20}.0.0/24"
  region                    = "${var.region}"
  network                   = google_compute_network.vpc.id
  private_ip_google_access  = true
}

module "cloud_nat" {
  source  = "../../modules/cloud_nat"
  project = var.project
  network = google_compute_network.vpc.name
  region  = var.region
}

module "gke_cluster" {
    source          = "../../modules/gke_cluster"
    cluster_name    = "${local.env}-binauthz"
    region          = var.region
    network         = google_compute_network.vpc.id
    subnetwork      = google_compute_subnetwork.subnet.id
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

# Artifact Registry repo for binauthz-demo
resource "google_artifact_registry_repository" "binauthz-demo-repo" {
  provider      = google-beta
  project       = var.project

  location      = var.region
  repository_id = "binauthz-demo-repo"
  description   = "Docker repository for binauthz demo"
  format        = "DOCKER"
}
