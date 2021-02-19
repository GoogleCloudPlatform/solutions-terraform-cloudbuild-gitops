resource "google_app_engine_application" "app" {
  project     = var.project
  location_id = "us-central"
  database_type = "CLOUD_DATASTORE_COMPATIBILITY"
}
