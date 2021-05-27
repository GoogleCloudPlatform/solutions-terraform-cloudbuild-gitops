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

#
#locals {
#  "env" = "dev"
#}
#
#provider "google" {
#  project = "${var.project}"
#}
#
#module "vpc" {
#  source  = "../../modules/vpc"
#  project = "${var.project}"
#  env     = "${local.env}"
#}
#
#module "http_server" {
#  source  = "../../modules/http_server"
#  project = "${var.project}"
#  subnet  = "${module.vpc.subnet}"
#}
#
#module "firewall" {
#  source  = "../../modules/firewall"
#  project = "${var.project}"
#  subnet  = "${module.vpc.subnet}"
#}

provider "google" {
  alias = "impersonate"

  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

data "google_service_account_access_token" "default" {
  provider               = google.impersonate
  target_service_account = "nycv-environments@nycv-terraform.iam.gserviceaccount.com"
  scopes                 = ["userinfo-email", "cloud-platform"]
  lifetime               = "900s"
}

provider "google" {
  access_token = data.google_service_account_access_token.default.access_token
  version      = "~> 3.12"
  project = local.project_id
  region  = "us-central1"
  zone    = "us-central1-c"
}

provider "google-beta" {
  access_token = data.google_service_account_access_token.default.access_token
  version      = "~> 3.12"
}

locals {
  env = "dev"
  project_id = "ny-dol-analytics"
  region  = "us-central1"
}

#provider "google" {
#  version = "3.5.0"
  #credentials = file("/downloads/instance.json")
#  project = local.project_id
#  region  = "us-central1"
#  zone    = "us-central1-c"
#}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network-03"
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "public-subnetwork" {
  name          = "terraform-subnetwork-03"
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
} 
