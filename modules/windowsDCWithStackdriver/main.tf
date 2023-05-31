#
#  Copyright 2019 Google Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
data "google_project" "project" {
}

#Setup a template for the windows startup bat file.  The bat files calls a powershell script so that is can get permissios to install stackdriver
data "template_file" "windowsstartup" {
  template = file("../../powershell/templates/windows-stackdriver-setup.ps1")

  vars = {
    environment  = var.environment
    projectname  = lower(data.google_project.project.name)
    computername = "${var.deployment-name}-${var.function}-${var.instancenumber}"
  }
}

locals {
  computername = "${var.deployment-name}-${var.function}-${var.instancenumber}"
}

resource "google_compute_disk" "datadisk" {
  name = "${local.computername}-pd-standard"
  zone = var.regionandzone
  type = "pd-standard"
  size = "200"
}

resource "google_runtimeconfig_config" "ad-runtime-config" {
  name        = var.runtime-config
  description = "Runtime configuration values for my service"
}

resource "google_compute_instance" "domain-controller" {
  name         = local.computername
  machine_type = var.machinetype
  zone         = var.regionandzone

  boot_disk {
    initialize_params {
      image = var.osimage
      size  = "200"
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = var.subnet-name
    network_ip = var.network-ip
    access_config {
    }
  }

  attached_disk {
    source      = "${local.computername}-pd-standard"
    device_name = "appdata"
  }

  depends_on = [google_compute_disk.datadisk]

  tags = var.network-tag

  metadata = {
    environment                = var.environment
    domain-name                = var.domain-name
    function                   = var.function
    region                     = var.region
    keyring                    = var.keyring
    runtime-config             = var.runtime-config
    deployment-name            = var.deployment-name
    kms-key                    = var.kms-key
    keyring-region             = var.kms-region
    gcs-prefix                 = var.gcs-prefix
    netbios-name               = var.netbios-name
    application                = "primary domain controller"
    windows-startup-script-ps1 = data.template_file.windowsstartup.rendered
    role                       = var.instancerole
    status-variable-path       = var.status-variable-path
    project-id                 = var.project
  }

  service_account {
    //scopes = ["storage-ro","monitoring-write","logging-write","trace-append"]
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

