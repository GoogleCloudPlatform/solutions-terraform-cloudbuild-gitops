terraform {

  required_version = "~>0.14"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~>4.5"
    }
  }
  
}

provider "google" {

  project     = "fiery-outpost-325706"
  region      = "asia-south1"
}

resource "google_compute_instance" "instance" {


  name         = "web-server"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  tags = ["web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network    = "default"
    #subnetwork = google_compute_subnetwork.vpc_subnet.name

    access_config {
      // Ephemeral public IP
    }
  }
}

