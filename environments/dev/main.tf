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
variable "notebook" {
  default = {
    "mwoo" = {
      "user_name" = "mwoo",
      "service_account" = "svc-mwoo"
    },
    "osolodilov" = {
      "user_name" = "osolodilov",
      "service_account" = "svc-osolodilov"
    },
    "jmerlin" = {
      "user_name" = "jmerlin",
      "service_account" = "svc-jmerlin"
    }
  }
}


resource "google_service_account" "service_account" {
  for_each = var.notebook
  account_id   = "${each.value.service_account}"
  display_name = "${each.value.user_name} Service Account"
}

resource "google_notebooks_instance" "instance" {
  for_each = var.notebook
  name = "${each.value.user_name}-python3"
  location = "us-west1-b"
  machine_type = "n1-standard-1"
  data_disk_type = "PD_STANDARD"
  lifecycle {
    ignore_changes = all
  }
  vm_image {
    project      = "deeplearning-platform-release"
    image_family = "common-cpu-notebooks"
  }
}