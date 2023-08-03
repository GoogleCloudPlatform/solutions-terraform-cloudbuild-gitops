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

/*
module cloud_ids {
  source = "GoogleCloudPlatform/terraform-google-cloud-ids"

  project_id                          = var.demo_project_id
  network_region                      = var.subnetwork_region
  vpc_network_name                    = var.vpc_network
  network_zone                        = "${var.subnetwork_region}-b"
  subnet_list = [
    var.vpc_subnet,
  ]
  ids_private_ip_range_name           = "ids-private-address"
  ids_private_ip_address              = "192.168.0.0"
  ids_private_ip_prefix_length        = 24
  ids_private_ip_description          = "Cloud IDS reserved IP Range"
  ids_name                            = "cloud-ids"
  severity                            = "INFORMATIONAL"
  packet_mirroring_policy_name        = "cloud-ids-packet-mirroring"
  packet_mirroring_policy_description = "Packet mirroring policy for Cloud IDS"
}
*/
resource "google_service_account" "ids_demo_service_account" {
  project      = var.demo_project_id
  account_id   = "ids-demo-service-account"
  display_name = "Service Account"
}

# Create Server Instance
resource "google_compute_instance" "ids_victim_server" {
  project      = var.demo_project_id
  name         = "ids-victim-server"
  machine_type = "e2-standard-2"
  zone         = "${var.subnetwork_region}-b"
  shielded_instance_config {
    enable_secure_boot = true
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
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
resource "google_compute_instance" "ids_attacker_machine" {
  project      = var.demo_project_id
  name         = "ids-attacker-machine"
  machine_type = "e2-standard-2"
  zone         = "${var.subnetwork_region}-b"
  shielded_instance_config {
    enable_secure_boot = true
  }
  #depends_on = [
  #  time_sleep.wait_enable_service_api_ids,
  #  google_compute_instance.ids_victim_server,
  #  google_compute_packet_mirroring.cloud_ids_packet_mirroring,
  #]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
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
    TARGET_IP = "${google_compute_instance.ids_victim_server.network_interface.0.network_ip}"
  }
  labels = {
    asset_type = "attacker-machine"
  }
}

# Enable SSH through IAP
resource "google_compute_firewall" "ids_allow_iap_proxy" {
  name      = "ids-allow-iap-proxy"
  network   = var.vpc_network
  project   = var.demo_project_id
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_service_accounts = [
    google_service_account.ids_demo_service_account.email
  ]
}

# Firewall rule to allow icmp & http
resource "google_compute_firewall" "ids_allow_http_icmp" {
  name      = "ids-allow-http-icmp"
  network   = var.vpc_network
  project   = var.demo_project_id
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["192.168.0.0/24"]
  target_service_accounts = [
    google_service_account.ids_demo_service_account.email
  ]
  allow {
    protocol = "icmp"
  }
}
