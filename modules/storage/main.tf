resource "google_storage_bucket" "tf-test-01" {
    name            = "tf-test-01"
    location        = "EU"
    force_destroy   = true

    uniform_bucket_level_access = true

    versioning {
        enabled     = true
    }
}