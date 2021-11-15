locals {
  network = "${element(split("-", var.subnet), 0)}"
}

resource "google_compute_router" "router" {
  project = "${var.project}"
  name    = "${local.network}-nat-router"
  network = "${local.network}"
  region  = "us-west1"
}

module "cloud-nat" {
  source                             = "terraform-google-modules/cloud-nat/google"
  version                            = "~> 2.0.0"
  project_id                         = "${var.project}"
  region                             = "us-west1"
  router                             = google_compute_router.router.name
  name                               = "${local.network}-nat-config"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
