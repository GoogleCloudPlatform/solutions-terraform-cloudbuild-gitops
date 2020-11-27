output "email" {
  value = "${google_monitoring_notification_channel.cap_notification_email.name}"
}