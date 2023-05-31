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

terraform {
  required_providers {
    google = {
      project = "${var.project}"
      source = "hashicorp/google"
      version = "4.67.0"
    }
  }
}

#module "vpc" {
#  source  = "../../modules/vpc"
#  project = "${var.project}"
#  env     = "${local.env}"
#}

#module "http_server" {
#  source  = "../../modules/http_server"
#  project = "${var.project}"
#  subnet  = "${module.vpc.subnet}"
#}

#module "firewall" {
#  source  = "../../modules/firewall"
#  project = "${var.project}"
#  subnet  = "${module.vpc.subnet}"
#}

module "create-network"{
  source = "../../modules/network"
  network-name    = "${local.deployment-name}-${local.environment}-net"
  primary-cidr    = "${local.primary-cidr}"
  second-cidr     = "${local.second-cidr}"
  third-cidr      = "${local.third-cidr}"
  fourth-cidr     = "${local.fourth-cidr}"
  primary-region  = "${local.region}"
  dr-region       = "${local.drregion}"
  deployment-name = "${local.deployment-name}"
}

//windows domain controller
module "windows-domain-controller" {
  source          = "../../modules/windowsDCWithStackdriver"
  project = "${var.project}"
  subnet-name     = "${module.create-network.subnet-name}"
  secondary-subnet-name = "${module.create-network.subnet-name}"
  instancerole    = "p"
  instancenumber  = "01"
  function        = "pdc"
  region          = "${local.region}"
  keyring         = "${local.keyring}"
  kms-key         = "${local.kms-key}"
  kms-region      ="${local.region}"
  environment     = "${local.environment}"
  regionandzone   = "${local.primaryzone}"
  osimage         = "${local.osimageWindows}"
  gcs-prefix      = "${local.gcs-prefix}"
  deployment-name = "${local.deployment-name}"
  domain-name     = "${local.domain}"
  netbios-name    = "${local.dc-netbios-name}"
  runtime-config  = "${local.runtime-config}"
  wait-on         = ""
  status-variable-path = "ad"
  network-tag     = ["pdc"]
  network-ip      = "10.0.0.100"
}

module "sql-server-alwayson-primary" {
  source = "../../modules/SQLServerWithStackdriver"
  project = "${var.project}"
  subnet-name = "${module.create-network.second-subnet-name}"
  alwayson-vip = "${local.second-cidr-alwayson}"
  wsfc-vip = "${local.second-cidr-wsfc}"
  instancerole = "p"
  instancenumber = "01"
  function = "sql"
  region = "${local.region}"
  keyring = "${local.keyring}"
  kms-key = "${local.kms-key}"
  kms-region="${local.region}"
  environment = "${local.environment}"
  regionandzone = "${local.primaryzone}"
  osimage = "${local.osimageSQL}"
  gcs-prefix = "${local.gcs-prefix}"
  deployment-name = "${local.deployment-name}"
  domain-name = "${local.domain}"
  netbios-name = "${local.dc-netbios-name}"
  runtime-config = "${local.runtime-config}"
  wait-on = "bootstrap/${local.deployment-name}/ad/success"
  domain-controller-address = "${module.windows-domain-controller.dc-address}"
  post-join-script-url = "${local.gcs-prefix}/powershell/bootstrap/install-sql-server-principal-step-1.ps1"
  status-variable-path = "mssql"
  network-tag = ["sql", "internal"]
  sql_nodes="${local.deployment-name}-sql-01|${local.deployment-name}-sql-02|${local.deployment-name}-sql-03"

}

 module "sql-server-alwayson-secondary" {
  source = "../../modules/SQLServerWithStackdriver"
  project = "${var.project}"
  subnet-name = "${module.create-network.third-subnet-name}"
  instancerole = "s"
  instancenumber = "02"
  function = "sql"
  region = "${local.region}"
  keyring = "${local.keyring}"
  kms-key = "${local.kms-key}"
  kms-region="${local.region}"
  environment = "${local.environment}"
  regionandzone = "${local.hazone}"
  osimage = "${local.osimageSQL}"
  gcs-prefix = "${local.gcs-prefix}"
  deployment-name = "${local.deployment-name}"
  domain-name = "${local.domain}"
  netbios-name = "${local.dc-netbios-name}"
  runtime-config = "${local.runtime-config}"
  wait-on = "bootstrap/${local.deployment-name}/ad/success"
  domain-controller-address = "${module.windows-domain-controller.dc-address}"
  post-join-script-url = "${local.gcs-prefix}/powershell/bootstrap/install-sql-server-principal-step-1.ps1"
  status-variable-path = "mssql"
  network-tag = ["sql", "internal"]
  sql_nodes="${local.deployment-name}-sql-01|${local.deployment-name}-sql-02|${local.deployment-name}-sql-03"
  alwayson-vip = "${local.third-cidr-alwayson}"
  wsfc-vip = "${local.third-cidr-wsfc}"
}

 module "sql-server-alwayson-secondary-2" {
  source = "../../modules/SQLServerWithStackdriver"
   project = "${var.project}"
  subnet-name = "${module.create-network.fourth-subnet-name}"
  instancerole = "s"
  instancenumber = "03"
  function = "sql"
  region = "${local.drregion}"
  keyring = "${local.keyring}"
  kms-key = "${local.kms-key}"
  kms-region="${local.region}"
  environment = "${local.environment}"
  regionandzone = "${local.drzone}"
  osimage = "${local.osimageSQL}"
  gcs-prefix = "${local.gcs-prefix}"
  deployment-name = "${local.deployment-name}"
  domain-name = "${local.domain}"
  netbios-name = "${local.dc-netbios-name}"
  runtime-config = "${local.runtime-config}"
  wait-on = "bootstrap/${local.deployment-name}/ad/success"
  domain-controller-address = "${module.windows-domain-controller.dc-address}"
  post-join-script-url = "${local.gcs-prefix}/powershell/bootstrap/install-sql-server-principal-step-1.ps1"
  status-variable-path = "mssql"
  network-tag = ["sql", "internal"]
  sql_nodes="${local.deployment-name}-sql-01|${local.deployment-name}-sql-02|${local.deployment-name}-sql-03"
  alwayson-vip = "${local.fourth-cidr-alwayson}"
  wsfc-vip = "${local.fourth-cidr-wsfc}"
}

