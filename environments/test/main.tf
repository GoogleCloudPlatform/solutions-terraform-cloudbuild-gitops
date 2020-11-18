locals {
  env = "test"
  region = "europe-west1"
}

provider "google" {
  project = "${var.project}"
}

module "storage" {
  source  = "../../modules/storage"
  project = "${var.project}"
  env     = "${local.env}"
  region  = "${local.region}"
}

module "cloudfunction" {
  source  = "../../modules/cloudfunction"
  project = "${var.project}"
  env     = "${local.env}"
  region  = "${local.region}"
  mds	  = "${module.storage.bucket}"
}

