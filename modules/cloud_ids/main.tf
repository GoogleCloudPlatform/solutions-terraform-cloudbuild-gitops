##  Copyright 2023 Google LLC
##  
##  Licensed under the Apache License, Version 2.0 (the "License");
##  you may not use this file except in compliance with the License.
##  You may obtain a copy of the License at
##  
##      https://www.apache.org/licenses/LICENSE-2.0
##  
##  Unless required by applicable law or agreed to in writing, software
##  distributed under the License is distributed on an "AS IS" BASIS,
##  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##  See the License for the specific language governing permissions and
##  limitations under the License.


##  This code creates PoC demo environment for Cloud IDS
##  This demo code is not built for production workload ##

resource "google_compute_global_address" "ids_producer_ip_range" {
  project       = var.project_id
  network       = var.vpc_network
  name          = "ids-producer-ip-range"
  description   = "Cloud IDS Producer IP Range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "192.168.0.0"
  prefix_length = 24
}

resource "google_service_networking_connection" "private_service_access" {
  network                 = var.vpc_network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.ids_producer_ip_range.name]
}

resource "google_cloud_ids_endpoint" "ids_demo_endpoint" {
  project  = var.project_id
  network  = var.vpc_network
  name     = "ids-demo-endpoint"
  location = "${var.subnetwork_region}-c"
  severity = "INFORMATIONAL"
  
  depends_on = [
    google_compute_global_address.ids_producer_ip_range,
    google_service_networking_connection.private_service_access,
  ]
}

resource "google_compute_packet_mirroring" "ids_demo_packet_mirroring" {
  project     = var.project_id
  region      = var.subnetwork_region
  name        = "ids-demo-packet-mirroring"
  description = "Packet Mirroring for Cloud IDS"
  network {
    url = var.vpc_network
  }
  mirrored_resources {
    subnetworks {
      url = var.vpc_subnet
    }
  }
  collector_ilb {
    url = google_cloud_ids_endpoint.ids_demo_endpoint.endpoint_forwarding_rule
  }
}

resource "google_service_account" "ids_demo_service_account" {
  project      = var.project_id
  account_id   = "ids-demo-service-account"
  display_name = "Service Account for Cloud IDS Demo"
}

# Create Server Instance
resource "google_compute_instance" "ids_demo_victim_server" {
  project      = var.project_id
  zone         = "${var.subnetwork_region}-c"
  name         = "ids-demo-victim-server"
  machine_type = "e2-micro"
  shielded_instance_config {
    enable_secure_boot = true
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = var.vpc_network
    subnetwork = var.vpc_subnet
  }

  service_account {
    email  = google_service_account.ids_demo_service_account.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = "apt-get update -y;apt-get install -y nginx;cd /var/www/html/;sudo touch eicar.file"
  labels = {
    asset_type = "victim-machine"
  }
}

# Create Attacker Instance
resource "google_compute_instance" "ids_demo_attacker_machine" {
  project      = var.project_id
  zone         = "${var.subnetwork_region}-c"
  name         = "ids-demo-attacker-machine"
  machine_type = "e2-micro"
  shielded_instance_config {
    enable_secure_boot = true
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = var.vpc_network
    subnetwork = var.vpc_subnet
  }

  service_account {
    email  = google_service_account.ids_demo_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = file("${path.module}/script/startup.sh")
  metadata = {
    TARGET_IP = "${google_compute_instance.ids_demo_victim_server.network_interface.0.network_ip}"
  }

  labels = {
    asset_type = "attacker-machine"
  }

  depends_on = [
    google_compute_instance.ids_demo_victim_server,
    google_compute_packet_mirroring.ids_demo_packet_mirroring,
  ]
}
