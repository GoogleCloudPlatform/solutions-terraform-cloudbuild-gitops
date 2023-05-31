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

resource "google_compute_subnetwork" "primary-subnetwork" {
  name          = "${var.network-name}-subnet-1"
  ip_cidr_range = "${var.primary-cidr}"
  region        = "${var.primary-region}"
  network       = "${google_compute_network.custom-network.self_link}"
}

resource "google_compute_subnetwork" "subnetwork-2" {
  name          = "${var.network-name}-subnet-2"
  ip_cidr_range = "${var.second-cidr}"
  region        = "${var.primary-region}"
  network       = "${google_compute_network.custom-network.self_link}"
}

resource "google_compute_subnetwork" "subnetwork-3" {
  name          = "${var.network-name}-subnet-3"
  ip_cidr_range = "${var.third-cidr}"
  region        = "${var.primary-region}"
  network       = "${google_compute_network.custom-network.self_link}"
}

resource "google_compute_subnetwork" "subnetwork-4" {
  name          = "${var.network-name}-subnet-4"
  ip_cidr_range = "${var.fourth-cidr}"
  region        = "${var.dr-region}"
  network       = "${google_compute_network.custom-network.self_link}"
}

resource "google_compute_network" "custom-network" {
  name                    = "${var.network-name}"
  auto_create_subnetworks = false
}

resource "google_compute_firewall" "default" {
  name    = "${var.deployment-name}-allow-remote-access"
  network = "${google_compute_network.custom-network.self_link}"


  allow {
    protocol = "tcp"
    ports    = ["3389", "8080"]
  }

  source_ranges = ["35.185.218.131/32"]
  target_tags = ["web","pdc","sql"]
}

resource "google_compute_firewall" "allow-internal" {
  name    = "${var.deployment-name}-allow-internal"
  network = "${google_compute_network.custom-network.self_link}"

  allow {
    protocol = "all"
  }

  source_tags = ["pdc","sql"]
  target_tags = ["sql","pdc"]
}

resource "google_compute_firewall" "healthchecks" {
  name    = "${var.deployment-name}-allow-healthcheck-access"
  network = "${google_compute_network.custom-network.self_link}"


  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }

  source_ranges = ["130.211.0.0/22","35.191.0.0/16"]
  target_tags = ["sql"]
}

resource "google_compute_firewall" "alwayson" {
  name    = "${var.deployment-name}-allow-alwayson-access"
  network = "${google_compute_network.custom-network.self_link}"


  allow {
    protocol = "tcp"
    ports    = ["5022"]
  }

  source_tags = ["sql"]
  target_tags = ["sql"]
}
