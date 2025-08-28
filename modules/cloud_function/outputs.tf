output "function_trigger_url" {
  value = google_cloudfunctions2_function.function.url
}

output "sa-email" {
  value = google_service_account.service_account.email
}

output "function_name" {
  value = google_cloudfunctions2_function.function.name
}
