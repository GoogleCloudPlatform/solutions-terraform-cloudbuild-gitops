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


# Enable the necessary API services
resource "google_project_service" "ids_api_service" {
  for_each = toset([
    "servicenetworking.googleapis.com",
    "ids.googleapis.com",
    "logging.googleapis.com",
    "compute.googleapis.com",
  ])
  service                    = each.key
  project                    = var.demo_project_id
  disable_on_destroy         = false
  disable_dependent_services = false
}

# wait delay after enabling APIs
resource "time_sleep" "wait_enable_service_api_ids" {
  depends_on       = [google_project_service.ids_api_service]
  create_duration  = "45s"
  destroy_duration = "45s"
}

#Get the default the service Account
data "google_compute_default_service_account" "default" {
  project    = var.demo_project_id
  depends_on = [time_sleep.wait_enable_service_api_ids]
}

# Create IDS Subnetwork
resource "google_compute_subnetwork" "ids_subnetwork" {
  name          = "ids-network"
  ip_cidr_range = "192.168.10.0/24"
  region        = var.subnetwork_region
  project       = var.demo_project_id
  network       = google_compute_network.ids_network.self_link
  # Enabling VPC flow logs
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
  private_ip_google_access = true
  depends_on = [
    google_compute_network.ids_network,
  ]
}

# Setup Private IP access
resource "google_compute_global_address" "ids_private_ip" {
  name          = "ids-private-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.10.10.0"
  prefix_length = 24
  network       = var.vpc_network
  project       = var.demo_project_id
  description   = "Cloud IDS IP Range"
  depends_on    = [time_sleep.wait_enable_service_api_ids]
}


# Create Private Connection:
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.ids_private_ip.name]
  depends_on              = [time_sleep.wait_enable_service_api_ids]
}

#Creating the IDS Endpoint
resource "google_cloud_ids_endpoint" "ids_endpoint" {
  name     = "cloud-ids-${var.vpc_network_name}"
  location = "${var.subnetwork_region}-b"
  network  = var.vpc_network
  severity = "INFORMATIONAL"
  project  = var.demo_project_id
  depends_on = [
    time_sleep.wait_enable_service_api_ids,
    google_compute_global_address.ids_private_ip,
    google_service_networking_connection.private_vpc_connection,
  ]
}

#Creating the packet mirroring policy for the subnet
resource "google_compute_packet_mirroring" "cloud_ids_packet_mirroring" {
  name        = "cloud-ids-packet-mirroring"
  description = "Packet Mirroring for IDS"
  project     = var.demo_project_id
  region      = var.subnetwork_region
  network {
    url = var.vpc_network
  }
  collector_ilb {
    url = google_cloud_ids_endpoint.ids_endpoint.endpoint_forwarding_rule
  }
  mirrored_resources {

    subnetworks {
      url = google_compute_subnetwork.ids_subnetwork.id
    }
  }
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
  source_ranges = ["10.10.0.0/24"]
  target_service_accounts = [
    data.google_compute_default_service_account.default.email
  ]
  allow {
    protocol = "icmp"
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
    data.google_compute_default_service_account.default.email
  ]
}

resource "google_service_account" "compute_service_account" {
  project      = var.demo_project_id
  account_id   = "compute-service-account"
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
  depends_on = [
    time_sleep.wait_enable_service_api_ids,
    google_compute_packet_mirroring.cloud_ids_packet_mirroring,
  ]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network    = var.vpc_network
    subnetwork = google_compute_subnetwork.ids_subnetwork.id
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
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
  depends_on = [
    time_sleep.wait_enable_service_api_ids,
    google_compute_instance.ids_victim_server,
    google_compute_packet_mirroring.cloud_ids_packet_mirroring,
  ]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network    = var.vpc_network
    subnetwork = google_compute_subnetwork.ids_subnetwork.id
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = data.google_compute_default_service_account.default.email
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
