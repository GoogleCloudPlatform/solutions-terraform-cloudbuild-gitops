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
  source  = "../../modules/vpc"
  project = "${var.project}"
  env     = "${local.env}"
  region  = "${var.region}"
}

module "cloud_nat" {
  source  = "../../modules/cloud_nat"
  project = "${var.project}"
  network = "${module.vpc.network}"
  region  = "${var.region}"
}
/*
module "gke_cluster" {
    source          = "../../modules/gke_cluster"
    cluster_name    = "${local.env}-binauthz"
    region          = var.region
    network         = module.vpc.network
    subnetwork      = module.vpc.subnet
    master_ipv4_cidr= "10.${local.env == "dev" ? 10 : 20}.1.16/28"
}
*/
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

resource "google_artifact_registry_repository" "my-repo" {
  provider      = google-beta
  project       = var.project

  location      = "us-central1"
  repository_id = "${local.env == "dev" ? "dev" : "prod"}-repo"
  description   = "Docker repository for binauthz demo"
  format        = "DOCKER"
}

resource "google_container_analysis_note" "note" {
  name = "${local.env == "dev" ? "build" : "qa"}-attestor-note"
  attestation_authority {
    hint {
      human_readable_name = "My Binary Authorization Demo!"
    }
  }
}

resource "google_binary_authorization_attestor" "attestor" {
  name = "${local.env == "dev" ? "build" : "qa"}-attestor"
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

# KMS resources
resource "google_kms_key_ring" "keyring" {
  name     = "binauthz-${local.env == "dev" ? "build" : "qa"}-keyring"
  location = "global"
}

resource "google_kms_crypto_key" "crypto-key" {
  name     = "${local.env == "dev" ? "build" : "qa"}-attestor-key"
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

/*
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
*/
