# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "google_project_service" "cloud_monitoring_api" {
  project = var.project_id
  service = "monitoring.googleapis.com"
}

resource "google_monitoring_notification_channel" "email" {
  provider     = google-beta
  project      = var.project_id
  display_name = "Email notification channel for VPC-SC denials"
  type         = "email"
  labels = {
    email_address = var.email_address
  }
  depends_on = [google_project_service.cloud_monitoring_api]
}

resource "google_monitoring_alert_policy" "vpcsc_denials_enforced" {
  provider     = google-beta
  project      = var.project_id
  display_name = "VPC-SC denials [ENFORCED]"
  combiner     = "OR"
  conditions {
    display_name = "Logging bucket - logging/user/${var.log_based_metric_name}"
    condition_threshold {
      threshold_value = 6
      duration        = "120s"
      comparison      = "COMPARISON_GT"
      trigger {
        count = 1
      }
      aggregations {
        per_series_aligner   = "ALIGN_COUNT"
        group_by_fields      = ["metric.label.projectId"]
        alignment_period     = "120s"
        cross_series_reducer = "REDUCE_SUM"
      }
      filter = "resource.type=\"logging_bucket\" AND metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" AND metric.labels.dryRun != \"true\""
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.name]
  alert_strategy {
    auto_close = "86400s" # 1 day
  }
  # severity = "WARNING"
  documentation {
    content   = "Please check the violations for enforced perimeters in project $${metric.labels.projectId}."
    mime_type = "text/markdown"
    # subject   = "Enforced VPC SC violations in project $${metric.labels.projectId}"
  }
  depends_on = [google_monitoring_notification_channel.email]
}

resource "google_monitoring_alert_policy" "vpcsc_denials_dry_run" {
  provider     = google-beta
  project      = var.project_id
  display_name = "VPC-SC denials [DRY RUN]"
  combiner     = "OR"
  conditions {
    display_name = "Logging bucket - logging/user/${var.log_based_metric_name}"
    condition_threshold {
      threshold_value = 6
      duration        = "120s"
      comparison      = "COMPARISON_GT"
      trigger {
        count = 1
      }
      aggregations {
        per_series_aligner   = "ALIGN_COUNT"
        group_by_fields      = ["metric.label.projectId"]
        alignment_period     = "120s"
        cross_series_reducer = "REDUCE_SUM"
      }
      filter = "resource.type=\"logging_bucket\" AND metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" AND metric.labels.dryRun = \"true\""
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.name]
  alert_strategy {
    auto_close = "86400s" # 1 day
  }
  # severity = "WARNING"
  documentation {
    content   = "Please check the violations for dry run perimeters in project $${metric.labels.projectId}."
    mime_type = "text/markdown"
    # subject   = "Dry run VPC SC violations in project $${metric.labels.projectId}"
  }
  depends_on = [google_monitoring_notification_channel.email]
}
