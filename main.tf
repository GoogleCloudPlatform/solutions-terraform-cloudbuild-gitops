locals {
  env = "dev"
}

provider "google" {
  project = "${var.project}"
}

resource "google_storage_bucket" "my_bucket" {
  name     = var.bucket_name
  location = var.region
  labels   = {
      test  = "demotest"
  }
}
