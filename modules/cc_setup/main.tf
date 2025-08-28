locals {
  split_project   = split("-","${var.project}")
  bank            = "${local.split_project[0]}"
  wrapped_keyset  = file("${path.module}/raw_files/${local.bank}_wrapped_keyset")
}

resource "google_storage_bucket" "input_bucket" {
  project       = var.project
  location      = var.region
  name          = "${var.project}-input-bucket"
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
}

resource "google_kms_secret_ciphertext" "encrypted_file" {
  provider      = google-beta
  crypto_key    = google_kms_crypto_key.encryption_key.id
  plaintext     = file("${path.module}/raw_files/${local.bank}_customer_list.csv")
}

resource "google_storage_bucket_object" "encrypted_object" {
  name          = "enc_${local.bank}_customer_list.csv"
  content       = google_kms_secret_ciphertext.encrypted_file.ciphertext
  bucket        = google_storage_bucket.input_bucket.name
}

resource "google_storage_bucket_object" "plaintext_object" {
  name          = "${local.bank}_customer_list.csv"
  content       = file("${path.module}/raw_files/${local.bank}_customer_list.csv")
  bucket        = var.source_bucket
}

# KMS resources
resource "google_kms_key_ring" "encryption_keyring" {
  project       = var.project
  location      = var.region
  name          = "${var.project}-sym-enc-kr"
}

resource "google_kms_crypto_key" "encryption_key" {
  name          = "${var.project}-sym-enc-key"
  key_ring      = google_kms_key_ring.encryption_keyring.id
  purpose       = "ENCRYPT_DECRYPT"

  version_template {
    algorithm           = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level    = "SOFTWARE"
  }
}

data "google_kms_crypto_key_version" "encryption_key_version" {
  crypto_key = google_kms_crypto_key.encryption_key.id
}

# Service Account
resource "google_service_account" "service_account" {
  project       = var.project
  account_id    = "${var.project}-sa"
  display_name  = "${var.project}-sa"
}

# IAM entry for service account to operate the cloud-kms key for GCS decryption
resource "google_kms_crypto_key_iam_member" "cloud_hsm_key_operator_gcs" {
  crypto_key_id = google_kms_crypto_key.encryption_key.id
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  member        = "serviceAccount:${google_service_account.service_account.email}"
}

# IAM entry for service account to operate the cloud-kms key for BQ decryption
resource "google_kms_crypto_key_iam_member" "cloud_hsm_key_operator_bq" {
  crypto_key_id = google_kms_crypto_key.encryption_key.id
  role          = "roles/cloudkms.cryptoKeyDecrypterViaDelegation"
  member        = "serviceAccount:${google_service_account.service_account.email}"
}

# Artifact Registry repo
resource "google_artifact_registry_repository" "artifact-repo" {
  provider      = google-beta
  project       = var.project
  location      = var.region
  repository_id = "${var.project}-repo"
  description   = "Docker repository confidential space demo"
  format        = "DOCKER"
}

data "google_project" "project" {
  project_id = var.project
}

resource "google_iam_workload_identity_pool" "workload_identity_pool" {
  provider                  = google-beta
  project                   = var.project
  workload_identity_pool_id = "${var.project}-pool"
  display_name              = "${var.project}-pool"
  description               = "Identity pool for confidential space demo"
}

# IAM entry for the workload identity pool to use the project service account
resource "google_service_account_iam_member" "workload_identity-role" {
  service_account_id = google_service_account.service_account.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.workload_identity_pool.name}/*"
}

# bigquery table plaintext
resource "google_bigquery_table" "customer_list" {
  deletion_protection   = false
  project               = var.source_project
  dataset_id            = var.source_dataset
  table_id              = "${local.bank}-customer-list"
}

resource "google_bigquery_job" "load_customer_data_job" {
  job_id     = "${local.bank}-load-customer-data-job"
  project    = var.source_project
  location   = var.region

  load {
    source_uris     = [
      "gs://${var.source_bucket}/${google_storage_bucket_object.plaintext_object.name}",
    ]

    destination_table {
      table_id      = google_bigquery_table.customer_list.id
    }

    skip_leading_rows       = 1
    schema_update_options   = ["ALLOW_FIELD_RELAXATION", "ALLOW_FIELD_ADDITION"]

    write_disposition       = "WRITE_TRUNCATE"
    autodetect              = true
  }
}

# bigquery dataset
resource "google_bigquery_dataset" "ccdemo_dataset" {
  project           = var.project
  location          = var.region
  dataset_id        = "ccdemo_dataset"
  friendly_name     = "ccdemo_dataset"
  description       = "This dataset is only meant for confidential collaboration"
}

# bigquery table encrypted
resource "google_bigquery_table" "enc_customer_list" {
  deletion_protection   = false
  project               = var.project
  dataset_id            = google_bigquery_dataset.ccdemo_dataset.dataset_id
  table_id              = "enc-customer-list"
}

resource "google_bigquery_job" "encrypt_customer_names_job" {
  job_id     = "encrypt-customer-names-job"
  project    = var.project
  location   = var.region

  query {
    query = <<EOF
      SELECT
        id,
        DETERMINISTIC_ENCRYPT(KEYS.KEYSET_CHAIN('gcp-kms://${google_kms_key_ring.encryption_keyring.id}/cryptoKeys/${google_kms_crypto_key.encryption_key.name}', ${local.wrapped_keyset}), name, '') AS enc_name,
        city
      FROM
        `${var.source_project}.${var.source_dataset}.${google_bigquery_table.customer_list.table_id}`;
    EOF

    destination_table {
      table_id = google_bigquery_table.enc_customer_list.id
    }

    allow_large_results = true
    flatten_results     = true
    write_disposition   = "WRITE_TRUNCATE"

    script_options {
      key_result_statement = "LAST"
    }
  }
}

# allow project service account read access to the bigquery dataset
resource "google_bigquery_dataset_iam_member" "bq_dataset_viewer" {
  project     = var.project
  dataset_id  = google_bigquery_dataset.ccdemo_dataset.dataset_id
  role        = "roles/bigquery.dataViewer"
  member      = "serviceAccount:${google_service_account.service_account.email}"
}

# allow project service account to create jobs in the project
resource "google_project_iam_member" "bq_job_user" {
  project     = var.project
  role        = "roles/bigquery.jobUser"
  member      = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_storage_bucket_object" "wrapped_keyset_decoded" {
  name          = "${local.bank}-wrapped-keyset"
  content       = local.wrapped_keyset
  bucket        = google_storage_bucket.input_bucket.name
}
