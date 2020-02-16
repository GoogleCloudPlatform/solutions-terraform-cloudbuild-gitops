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



resource "google_compute_instance" "http_server" {
  project      = "gred-ptddtalak-sb-001-e4372d8c"
  zone         = "us-west1-a"
  name         = "arjun-tf"
  machine_type = "f1-micro"

  boot_disk {
    initialize_params {
      image = "devops-prd-001-b276fe04/image-rsc-rhel-7-5-v20181011"
    }
  }

  network_interface {
    subnetwork = "sub-prv-usw1-01"

    access_config {
      # Include this section to give the VM an external ip address
    }
  }

  # Apply the firewall rule to allow external IPs to access this instance
  tags = ["http-server"]
}
