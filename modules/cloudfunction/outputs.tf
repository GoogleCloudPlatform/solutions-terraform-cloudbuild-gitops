output "cf_clientAgeVal" {
  value = "${google_cloudfunctions_function.client_age_validation_cf.https_trigger_url}"
}

output "cf_duePayVal" {
  value = "${google_cloudfunctions_function.due_payments_validation_cf.https_trigger_url}"
}

output "cf_effortRateNewCredVal" {
  value = "${google_cloudfunctions_function.effort_rate_new_credit_validation_cf.https_trigger_url}"
}

output "cf_effortRateTotalCredVal" {
  value = "${google_cloudfunctions_function.effort_rate_total_credit_validation_cf.https_trigger_url}"
}

output "cf_jsonToBase64" {
  value = "${google_cloudfunctions_function.json_to_base64_cf.https_trigger_url}"
}