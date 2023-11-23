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
  region = "${var.region}"
}

 module "http_server_nginx" {
  source  = "../../modules/http_server_nginx"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
  region = "${var.region}"
}

module "firewall" {
  source  = "../../modules/firewall"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
}

module "cloud_nat" {
  source  = "../../modules/cloud_nat"
  project = "${var.project}"
  region =  "${var.region}"
  cloud_router = "${module.cloud_router.cloud_router}"

}

module "cloud_router" {
  source  = "../../modules/cloud_router"
  project = "${var.project}"
  region =  "${var.region}"
  env = "${var.env}"
}