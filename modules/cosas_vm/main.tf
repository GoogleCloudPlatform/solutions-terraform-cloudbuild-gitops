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

data "google_compute_image" "vmimage" {
  family  = "ubuntu-minimal-2004"
  project = "ubuntu-os-cloud"
}

resource "google_compute_instance" "cosas_vm" {
  name         = "cosasvm01"
  machine_type = "f1-micro"
  project      = var.project
  zone         = var.zone

  metadata_startup_script = file("${path.module}/scripts/provision.sh")

  boot_disk {
    initialize_params {
      image = data.google_compute_image.vmimage.self_link
    }
  }

  network_interface {
    # A default network is created for all GCP projects
    network = "default"
    access_config {
    }
  }
}
