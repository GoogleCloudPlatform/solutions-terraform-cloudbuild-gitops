output "service_name" {
  value       = module.cloud_run.service_name
  description = "Name of the created service"
}

output "revision" {
  value       = module.cloud_run.revision
  description = "Deployed revision for the service"
}

output "service_url" {
  value       = module.cloud_run.service_url
  description = "The URL on which the deployed service is available"
}

output "service_id" {
  value       = module.cloud_run.service_id
  description = "Unique Identifier for the created service"
}

output "service_status" {
  value       = module.cloud_run.service_status
  description = "Status of the created service"
}

output "service_location" {
  value       = module.cloud_run.location
  description = "Location in which the Cloud Run service was created"
}