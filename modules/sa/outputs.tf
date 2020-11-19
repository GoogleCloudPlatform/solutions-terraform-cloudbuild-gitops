output "cf_sa" {
  value = "${google_service_account.cap_multicloud_sa.email}"
}

output "mig_sa" {
  value = "${google_service_account.cap_mig_sa.email}"
}