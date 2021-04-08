# Create a GCS Bucket
resource "google_storage_bucket" "dataops_bucket" {
  name          = var.bucket_name
  location      = var.region
  force_destroy = false
}
