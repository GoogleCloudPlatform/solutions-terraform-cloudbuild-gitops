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

module "cloud_function" {
    source          = "../../modules/cloud_function"
    project         = "${var.project}"
    function-name   = "admin-access"
    function-desc   = "intakes requests from slack for just-in-time admin access to a project"
    entry-point     = "admin_access"
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