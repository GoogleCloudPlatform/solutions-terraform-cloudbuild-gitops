
resource "google_compute_router" "router" {
  project = "${var.project}"
  name    = "${var.network}-nat-router"
  network = "${var.network}"
  region  = "${var.region}"
}

module "cloud-nat" {
  source                             = "terraform-google-modules/cloud-nat/google"
  version                            = "~> 2.0.0"
  project_id                         = "${var.project}"
  region                             = "${var.region}"
  router                             = google_compute_router.router.name
  name                               = "${var.network}-nat"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
