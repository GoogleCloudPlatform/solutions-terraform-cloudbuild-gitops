locals {
  env = "test"
  region = "europe-west1"
}

provider "google" {
  project = "${var.project}"
  region = "${local.region}"
}

module "sa" {
  source  = "../../modules/sa"
  project = "${var.project}"
  env     = "${local.env}"
  region  = "${local.region}"
}

module "storage" {
  source  = "../../modules/storage"
  project = "${var.project}"
  env     = "${local.env}"
  region  = "${local.region}"
}

module "pubsub" {
  source  = "../../modules/pubsub"
  project = "${var.project}"
  env     = "${local.env}"
  region  = "${local.region}"
}

module "cloudfunction" {
  source   					= "../../modules/cloudfunction"
  project  					= "${var.project}"
  env      					= "${local.env}"
  region   					= "${local.region}"
  mds	   					= "${module.storage.mds}"
  main_bucket			    = "${module.storage.main_bucket}"
  sa_email 					= "${module.sa.cf_sa}"
  cf_sendmail_pubsub 		= "${module.pubsub.credditApprovalNotification}"
  cf_triggerworkflow_pubsub = "${module.pubsub.credditApprovalValidation}"
}