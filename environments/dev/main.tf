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

module "gke_cluster" {
    source          = "../../modules/gke_cluster"
    cluster_name    = "${local.env}-binauthz-demo"
    region          = var.region
    network         = module.vpc.network
    subnetwork      = module.vpc.subnet
    master_ipv4_cidr= "10.${local.env == "dev" ? 10 : 20}.12.16/28"
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

module "cloud_nat" {
  source  = "../../modules/cloud_nat"
  project = "${var.project}"
  subnet  = "${module.vpc.subnet}"
}
*/
