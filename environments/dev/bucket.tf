# Create a GCS Bucket
resource "google_storage_bucket" "dataops_bucket" {
  name          = "my-dataops-bucket-123"
  location      = var.region
  force_destroy = false
}
