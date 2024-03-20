provider "google" {
  region = "us-central1"
  project = "test"
}

resource "google_compute_instance" "my_instance" {
  zone = "us-central1-a"
  name = "test"

  machine_type = "n1-standard-16" # <<<<<<<<<< Try changing this to n1-standard-32 to compare the costs
  network_interface {
    network = "default"
    access_config {}
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  scheduling {
    preemptible = true
  }

  guest_accelerator {
    type = "nvidia-tesla-t4" # <<<<<<<<<< Try changing this to nvidia-tesla-p4 to compare the costs
    count = 4
  }

  labels = {
    environment = "production"
    service = "web-app"
  }
}

resource "google_cloudfunctions_function" "my_function" {
  runtime = "nodejs20"
  name = "test"
  available_memory_mb = 512

  labels = {
    environment = "Prod"
  }
}
