##### CLIENT AGE VALIDATION #####

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
 service_account_email = "${var.sa_email}"
 runtime               = "python38"
 trigger_http          = true
}

##### DUE PAYMENTS VALIDATION #####

data "archive_file" "due_payments_validation_zip" {
  type        = "zip"
  source_dir  = "${path.module}/due_payments_validation"
  output_path = "${path.module}/files/due_payments_validation.zip"
}

# Storing zip to be used in the due_payments_validation cf
resource "google_storage_bucket_object" "due_payments_validation_obj" {
  name   = "cfs/due_payments_validation.zip"
  bucket = "${var.mds}"
  source = "${data.archive_file.due_payments_validation_zip.output_path}"
  depends_on = [data.archive_file.due_payments_validation_zip]
}

# due_payments_validation cf
resource "google_cloudfunctions_function" "due_payments_validation_cf" {
 name                  = "due_payments_validation"
 description           = "CF to validate due payments"
 available_memory_mb   = 128
 source_archive_bucket = "${var.mds}"
 source_archive_object = "${google_storage_bucket_object.due_payments_validation_obj.name}"
 timeout               = 60
 entry_point           = "due_payments_validation"
 ingress_settings      = "ALLOW_ALL"
 service_account_email = "${var.sa_email}"
 runtime               = "python38"
 trigger_http          = true
}