# Service Account to be used by Cloud Function
resource "google_service_account" "cap_multicloud_sa" {
    account_id   = "cap-multicloud-${var.env}"
    display_name = "Cloud Function Service Account"
}

# Set sample role for CF SA
resource "google_project_iam_member" "cap_multicloud_sa_editor" {
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.cap_multicloud_sa.email}"
}

data "archive_file" "client_age_validation_zip" {
  type        = "zip"
  source_dir  = "${path.module}/client_age_validation"
  output_path = "${path.module}/files/client_age_validation.zip"
}

# Storing zip to be used in the client_age_validation cf
resource "google_storage_bucket_object" "client_age_validation_obj" {
  name   = "cfs/client_age_validation.zip"
  bucket = "${var.mds}"
  source = "${data.archive_file.client_age_validation_zip.output_path}"
  depends_on = [data.archive_file.client_age_validation_zip]
}

# client_age_validation cf
resource "google_cloudfunctions_function" "client_age_validation_cf" {
 name                  = "client_age_validation"
 description           = "CF to validate the client age"
 available_memory_mb   = 128
 source_archive_bucket = "${var.mds}"
 source_archive_object = "${google_storage_bucket_object.client_age_validation_obj.name}"
 timeout               = 60
 entry_point           = "client_age_validation"
 ingress_settings      = "ALLOW_ALL"
 service_account_email = "${google_service_account.cap_multicloud_sa.email}"
 runtime               = "python37"
 trigger_http          = true
}