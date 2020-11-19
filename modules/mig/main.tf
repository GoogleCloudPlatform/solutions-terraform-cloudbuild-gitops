# Custom VPC for InnerCity-Stores
resource "google_compute_network" "cap_network" {
  name                    = "cap-network"
  auto_create_subnetworks = "false"
}

# Subnet for InnerCity-Stores custom VPC
resource "google_compute_subnetwork" "cap_subnet" {
  name                     = "cap-subnet"
  ip_cidr_range            = "10.3.4.0/24"
  network                  = "${google_compute_network.cap_network.self_link}"
  region                   = "${var.region}"
  private_ip_google_access = false
}

# Firewall for load balancing on custom VPC
resource "google_compute_firewall" "vpc_cap_fw_lb" {
  name          = "cap-fw-lb"
  network       = google_compute_network.cap_network.name
  priority      = 1000
  direction     = "INGRESS"
  source_ranges = ["10.3.4.0/24"]

  allow {
    protocol = "all"
  }
}

# Firewall for health check on custom VPC
resource "google_compute_firewall" "vpc_cap_fw_hc" {
  name          = "cap-fw-mig"
  network       = google_compute_network.cap_network.name
  priority      = 1000
  direction     = "INGRESS"
  target_tags   = ["allow-mig-cap"]
  source_ranges = ["209.85.152.0/22","209.85.204.0/22","35.235.240.0/20","109.48.246.86","82.154.14.118"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Health Check for Backend VM used by SFTP MIG
resource "google_compute_health_check" "cap_mig_hc" {
  name = "cap-mig-hc"

  timeout_sec         = 10
  check_interval_sec  = 20
  healthy_threshold   = 2
  unhealthy_threshold = 3

  tcp_health_check {
    port = "22"
  }
}

# Managed Instace Group resources, template and group manager
resource "google_compute_region_autoscaler" "cap_mig_autoscaler" {
  depends_on = [google_compute_region_instance_group_manager.cap_mig]
  name    = "cap-mig-autoscaler"
  project = "${var.project}"
  region  = "${var.region}"
  target  = google_compute_region_instance_group_manager.cap_mig.id
  
  autoscaling_policy {
    max_replicas  = 3
    min_replicas  = 1
    cooldown_period = 200
    
    cpu_utilization {
      target = 0.8
    }
  }
}

resource "google_compute_instance_template" "cap_mig_template" {
  name_prefix     = "cap-mig-template-"
  machine_type    = "e2-highcpu-2"
  region          = "${var.region}"
  tags            = ["allow-mig-cap"]
  disk {
    source_image = "centos-8-v20201014"
    auto_delete  = true
    boot         = true
    disk_type    = "pd-standard"
    disk_size_gb = 20
  }  

  scheduling {
    automatic_restart = false
    preemptible       = true
  }

  metadata = {
    enable-oslogin = "True"
    startup-script-url = "gs://cap-archive-mds-${var.env}/cap-template-ss.sh"
  }

  // networking
  network_interface {
    subnetwork = "${google_compute_subnetwork.cap_subnet.self_link}"
    access_config {
      network_tier = "PREMIUM"
    }
  }

  service_account {
    email   = "${var.sa_email}"
    scopes  = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_pool" "cap_mig_targetpool" {
  name  = "cap-mig-targetpool"
  project = "${var.project}"
  region  = "${var.region}"
}

resource "google_compute_region_instance_group_manager" "cap_mig" {
  name                       = "cap-mig"
  base_instance_name         = "cap-mig"
  region                     = "${var.region}"
  distribution_policy_zones  = "${var.mig_region}"

  version {  
    instance_template = google_compute_instance_template.cap_mig_template.id
  }
  
  target_pools  = [google_compute_target_pool.cap_mig_targetpool.self_link]

  auto_healing_policies {
    health_check      = google_compute_health_check.cap_mig_hc.id
    initial_delay_sec = 300
  }
}

// Forwarding rule for Internal Load Balancing
resource "google_compute_forwarding_rule" "cap_mig_frule" {
  depends_on = [google_compute_subnetwork.cap_subnet,google_compute_address.cap_mig_ip]
  name   = "cap-mig-frule"
  region = "${var.region}"
  target                = google_compute_target_pool.cap_mig_targetpool.id
  # ports                 = ["22"]
  # port_range            = "25"
  ip_address            = "${google_compute_address.cap_mig_ip.address}"
}

resource "google_compute_address" "cap_mig_ip" {
  name = "cap-mig-ip"
}