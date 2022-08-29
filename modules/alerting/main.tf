# Alert Notification Channel
resource "google_monitoring_notification_channel" "basic" {
  display_name = var.notification_channel_display_name
  type         = var.channel_type
  labels = {
    email_address = var.email_address
  }
}

# Resource Utilization Alerts
resource "google_monitoring_alert_policy" "utilization_alert_policy" {
  display_name = var.display_name
  enabled      = var.enabled
  combiner     = var.combiner
  conditions {
    display_name = "CPU Utilization"
    condition_threshold {
      filter     = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\" AND metric.label.instance_name=\"${var.instance_name}\""
      duration   = var.duration
      comparison = var.comparison
      aggregations {
        alignment_period   = var.alignment_period
        per_series_aligner = "ALIGN_MEAN"
      }
      threshold_value = var.cpu_threshold_value
      trigger {
        count = var.violation_count
      }
    }
  }
  conditions {
    display_name = "Memory Utilization"
    condition_threshold {
      filter     = "metric.type=\"agent.googleapis.com/memory/percent_used\" resource.type=\"gce_instance\" metric.label.\"state\"=\"used\" metadata.user_labels.\"name\"=\"${var.instance_name}\""
      duration   = var.duration
      comparison = var.comparison
      aggregations {
        alignment_period   = var.alignment_period
        per_series_aligner = "ALIGN_MEAN"
      }
      threshold_value = var.memory_threshold_value
      trigger {
        count = var.violation_count
      }
    }
  }
  conditions {
    display_name = "Disk Utilization"
    condition_threshold {
      filter     = "metric.type=\"agent.googleapis.com/disk/percent_used\" resource.type=\"gce_instance\" metadata.user_labels.\"name\"=\"${var.instance_name}\" metric.label.\"state\"=\"used\" metric.label.\"device\"!=\"loop0\" metric.label.\"device\"!=\"loop1\" metric.label.\"device\"!=\"loop2\" metric.label.\"device\"!=\"loop3\" metric.label.\"device\"!=\"loop4\" metric.label.\"device\"!=\"loop5\" metric.label.\"device\"!=\"loop6\" metric.label.\"device\"!=\"tmpfs\""
      duration   = var.duration
      comparison = var.comparison
      aggregations {
        alignment_period   = var.alignment_period
        per_series_aligner = "ALIGN_MEAN"
      }
      threshold_value = var.disk_threshold_value
      trigger {
        count = var.violation_count
      }
    }
  }

  documentation {
    content = "Resource Utilization $${condition.display_name} has generated this alert for the $${metric.display_name}."
  }
  notification_channels = [
    "${google_monitoring_notification_channel.basic.id}",
  ]
}
