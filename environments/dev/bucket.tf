# Specify the GCP Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Create a GCS Bucket
resource "google_storage_bucket" "dataops_bucket" {
  name                        = var.bucket_name
  project                     = var.project_id
  location                    = var.region
  storage_class               = "REGIONAL"
  force_destroy               = true
  uniform_bucket_level_access = true
}
