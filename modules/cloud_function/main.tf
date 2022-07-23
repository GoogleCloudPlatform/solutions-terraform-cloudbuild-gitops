resource "google_storage_bucket" "bucket" {
  name                          = "${var.project}-source-code"
  location                      = "us-central1"
  uniform_bucket_level_access   = true
}

data "archive_file" "cf_source_zip" {
  type        = "zip"
  source_dir  = "../../functions/${var.function-name}"
  output_path = "${path.module}/tmp/some-name.zip"
}

resource "google_storage_bucket_object" "archive" {
  name          = "${var.function-name}-index.zip"
  bucket        = google_storage_bucket.bucket.name
  source        = data.archive_file.cf_source_zip.output_path
  content_type  = "application/zip"
}

resource "google_cloudfunctions_function" "function" {
  project     = "${var.project}"
  region      = "us-central1"
  name        = "${var.function-name}"
  description = "${var.function-desc}"
  runtime     = "python39"

  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  trigger_http          = true
  ingress_settings      = "ALLOW_ALL"
  entry_point           = "${var.entry-point}"
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
