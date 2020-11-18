output "cf_sa" {
  value = "${google_service_account.cap_multicloud_sa.email}"
}

output "cloudfunction_clientAgeVal" {
  value = "${google_cloudfunctions_function.client_age_validation_cf.name}"
}