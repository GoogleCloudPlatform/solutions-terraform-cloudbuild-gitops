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
  template = file("../powershell/templates/windows-stackdriver-setup.ps1")

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

resource "google_compute_instance" "sqlserver" {
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
    alias_ip_range {
      ip_cidr_range = var.alwayson-vip
    }
    alias_ip_range {
      ip_cidr_range = var.wsfc-vip
    }
    access_config {
      // Ephemeral IP
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
    domain-controller-address  = var.domain-controller-address
    instancerole               = var.instancerole
    function                   = var.function
    region                     = var.region
    keyring                    = var.keyring
    keyring-region             = var.kms-region
    runtime-config             = var.runtime-config
    kms-key                    = var.kms-key
    gcs-prefix                 = var.gcs-prefix
    netbios-name               = var.netbios-name
    application                = "SQLServer AlwaysOn"
    windows-startup-script-ps1 = data.template_file.windowsstartup.rendered
    role                       = var.instancerole
    wait-on                    = var.wait-on
    project-id                 = lower(data.google_project.project.project_id)
    post-join-script-url       = var.post-join-script-url
    sql_nodes                  = var.sql_nodes
  }

  service_account {
    //scopes = ["storage-ro","monitoring-write","logging-write","trace-append"]
    scopes = ["cloud-platform", "https://www.googleapis.com/auth/cloudruntimeconfig", "storage-rw"]
  }
}

