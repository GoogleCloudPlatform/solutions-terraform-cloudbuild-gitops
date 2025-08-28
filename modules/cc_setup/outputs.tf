output "input_bucket" {
  value = google_storage_bucket.input_bucket.name
}

output "pool_id" {
  value = google_iam_workload_identity_pool.workload_identity_pool.workload_identity_pool_id
}

output "repo_name" {
  value = google_artifact_registry_repository.artifact-repo.name
}
