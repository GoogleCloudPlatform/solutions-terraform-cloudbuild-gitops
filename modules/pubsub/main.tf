# Create PubSub Topic for Credit Notification
resource "google_pubsub_topic" "creditapproval-notification" {
  name   = "creditapproval-notification-${var.env}"
}

# Create Subscription for the Credit Notification
resource "google_pubsub_subscription" "creditapproval-notification-sub" {
  name  = "creditapproval-notification-sub-${var.env}"
  topic = google_pubsub_topic.creditapproval-notification.name
  retain_acked_messages = false
  ack_deadline_seconds = 10
}

# Create PubSub Topic for Credit Validation
resource "google_pubsub_topic" "creditapproval-validation" {
  name   = "creditapproval-validation-${var.env}"
}

# Create Subscription for the Credit Validation
resource "google_pubsub_subscription" "creditapproval-validation-sub" {
  name  = "creditapproval-validation-sub-${var.env}"
  topic = google_pubsub_topic.creditapproval-validation.name
  retain_acked_messages = false
  ack_deadline_seconds = 10
}