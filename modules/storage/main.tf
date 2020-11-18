resource "google_storage_bucket" "cap-archive-mds" {
  name          = "cap-archive-mds-${var.env}"
  location      = "${var.region}"
  force_destroy = true

  lifecycle_rule {
    condition {
      age = "7"
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_object" "mig-sftp-ss" {
  name   = "cap-template-ss.sh"
  content = file("${path.module}/files/cap-template-ss.sh")
  bucket = "${google_storage_bucket.cap-archive-mds.name}"
}