output "credditApprovalNotification" {
  value = "${google_pubsub_topic.creditapproval-notification.name}"
}

output "credditApprovalValidation" {
  value = "${google_pubsub_topic.creditapproval-validation.name}"
}