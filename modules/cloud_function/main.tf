resource "google_storage_bucket" "bucket" {
  name     = "${var.project}-source-code"
  location = "us-central1"
}

resource "google_storage_bucket_object" "archive" {
  name   = "${var.function-name}-index.zip"
  bucket = google_storage_bucket.bucket.name
  source = "../../functions/${var.function-name}"
}

resource "google_cloudfunctions_function" "function" {
  name        = "${var.function-name}"
  description = "${var.function-desc}"
  runtime     = "python39"

  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  trigger_http          = true
  ingress_settings      = "ALLOW_ALL"
  entry_point           = "${var.function-name}"
  service_account_email = google_service_account.service_account.email
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "google_service_account" "service_account" {
  account_id   = "sa-${var.function-name}"
  display_name = "sa-${var.function-name}"
}
