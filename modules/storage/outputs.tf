output "bucket" {
  value = "${google_storage_bucket.cap-archive-mds.name}"
}

output "startup-script" {
  value = "${google_storage_bucket_object.mig-sftp-ss.name}"
}