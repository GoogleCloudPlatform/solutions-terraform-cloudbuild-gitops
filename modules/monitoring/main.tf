resource "google_monitoring_alert_policy" "cap_alertpolicy_mig" {
  combiner = "OR"

  conditions {
    condition_threshold {
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }

      comparison      = "COMPARISON_LT"
      duration        = "0s"
      filter          = "metric.type=\"compute.googleapis.com/instance_group/size\" resource.type=\"instance_group\" resource.label.\"instance_group_name\"=${var.mig_name}"
      threshold_value = "1"

      trigger {
        count   = "1"
        percent = "0"
      }
    }

    display_name = "MIG without instances"
  }

  display_name = "MIG down"

  documentation {
    content   = "All instances in Managed Instance Group are down. SFTP server is down."
    mime_type = "text/markdown"
  }

  enabled               = "true"
  notification_channels = ["${google_monitoring_notification_channel.cap_notification_email.name}"]
}

resource "google_monitoring_alert_policy" "cap_alertpolicy_cf" {
  combiner = "OR"

  conditions {
    condition_threshold {
      aggregations {
        alignment_period     = "300s"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.function_name"]
        per_series_aligner   = "ALIGN_COUNT"
      }

      comparison      = "COMPARISON_GT"
      duration        = "0s"
      filter          = "metric.type=\"logging.googleapis.com/log_entry_count\" resource.type=\"cloud_function\" metric.label.\"severity\"=\"ERROR\" resource.label.\"function_name\"=\"storage-to-bq\""
      threshold_value = "1"

      trigger {
        count   = "1"
        percent = "0"
      }
    }

    display_name = "Log entries for ERROR in storage-to-bq- function"
  }

  conditions {
    condition_threshold {
      aggregations {
        alignment_period     = "300s"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.function_name"]
        per_series_aligner   = "ALIGN_COUNT"
      }

      comparison      = "COMPARISON_GT"
      duration        = "0s"
      filter          = "metric.type=\"logging.googleapis.com/log_entry_count\" resource.type=\"cloud_function\" resource.label.\"function_name\"=\"send-email\" metric.label.\"severity\"=\"ERROR\""
      threshold_value = "1"

      trigger {
        count   = "1"
        percent = "0"
      }
    }

    display_name = "Log entries for ERROR in send-semail"
  }

  display_name = "Errors in Function"

  documentation {
    content   = "There are errors in Cloud Function flows. Please check incident for function details."
    mime_type = "text/markdown"
  }

  enabled               = "true"
  notification_channels = ["${google_monitoring_notification_channel.cap_notification_email.name}"]
}

resource "google_monitoring_alert_policy" "cap_alertpolicy_pubsub" {
  combiner = "OR"

  conditions {
    condition_threshold {
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }

      comparison      = "COMPARISON_GT"
      duration        = "0s"
      filter          = "metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\" resource.type=\"pubsub_subscription\" resource.label.\"subscription_id\"=\"gcf-send-email-${var.region}-creditapproval-notification-${var.env}\""
      threshold_value = "600"

      trigger {
        count   = "1"
        percent = "0"
      }
    }

    display_name = "Unacked Messages in  creditapproval-notification-${var.env} Topic"
  }

  conditions {
    condition_threshold {
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }

      comparison      = "COMPARISON_GT"
      duration        = "0s"
      filter          = "metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\" resource.type=\"pubsub_subscription\" resource.label.\"subscription_id\"=\"gcf-trigger-workflow-${var.region}-creditapproval-validation-${var.env}\""
      threshold_value = "600"

      trigger {
        count   = "1"
        percent = "0"
      }
    }

    display_name = "Unacked Messages in creditapproval-validation-${var.region} Topic"
  }

  display_name = "Unacked messages on Topics"

  documentation {
    content   = "There are messages not being consumed from Topics. Please check the incident for more details."
    mime_type = "text/markdown"
  }

  enabled               = "true"
  notification_channels = ["${google_monitoring_notification_channel.cap_notification_email.name}"]
}

resource "google_monitoring_notification_channel" "cap_notification_email" {
  display_name = "Maintenance_Email"
  enabled      = "true"

  labels = {
    email_address = "cap.multicloud@gmail.com"
  }

  type    = "email"
}
