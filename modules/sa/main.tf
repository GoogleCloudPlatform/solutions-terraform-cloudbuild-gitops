# Service Account to be used by Cloud Function
resource "google_service_account" "cap_multicloud_sa" {
    account_id   = "cap-multicloud-${var.env}"
    display_name = "Cloud Function Service Account"
}

# Set sample role for CF SA
resource "google_project_iam_member" "cap_multicloud_sa_editor" {
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.cap_multicloud_sa.email}"
}