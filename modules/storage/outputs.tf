output "mds" {
  value = "${google_storage_bucket.cap-archive-mds.name}"
}

output "main_bucket" {
  value = "${google_storage_bucket.reports-main-bucket.name}"
}

output "startup-script" {
  value = "${google_storage_bucket_object.mig-sftp-ss.name}"
}