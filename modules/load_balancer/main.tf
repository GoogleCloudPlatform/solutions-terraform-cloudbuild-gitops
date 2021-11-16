locals {
  network = "${element(split("-", var.subnet), 0)}"
}

module "load_balancer" {
  source       = "GoogleCloudPlatform/lb/google"
  version      = "~> 2.0.0"
  region       = "us-west1"
  name         = "${local.network}-load-balancer"
  service_port = 80
  target_tags  = ["webserver"]
  project      = "${var.project}"
  network      = "${local.network}"
}

resource "google_compute_region_instance_group_manager" "webserver" {
  name               = "${local.network}-webserver-igm"
  base_instance_name = "${local.network}-webserver"
  project            = "${var.project}"
  region             = "us-west1"
  
  version {
    instance_template = "${var.instance_template_id}"
  }
  
  target_size       = 2
  target_pools      = [module.load_balancer.target_pool]
  
  named_port {
    name = "http"
    port = 80
  }

  update_policy {
    type                         = "PROACTIVE"
    instance_redistribution_type = "PROACTIVE"
    minimal_action               = "REPLACE"
    replacement_method           = "RECREATE"
  }
}
