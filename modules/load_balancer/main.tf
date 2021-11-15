locals {
  network = "${element(split("-", var.subnet), 0)}"
}

module "load_balancer" {
  source       = "GoogleCloudPlatform/lb/google"
  version      = "~> 2.0.0"
  region       = "us-west1"
  name         = "load-balancer"
  service_port = 80
  target_tags  = ["allow-lb-service"]
  project      = "${var.project}"
  network      = "${local.network}"
}

module "managed_instance_group" {
  source            = "terraform-google-modules/vm/google//modules/mig"
  version           = "~> 1.0.0"
  region            = "us-west1"
  target_size       = 2
  hostname          = "mig-simple"
  instance_template = "${var.instance_template_self_link}"
  target_pools      = [module.load_balancer.target_pool]
  named_ports = [{
    name = "http"
    port = 80
  }]
}
