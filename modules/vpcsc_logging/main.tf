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

resource "google_project_service" "cloud_resource_manager_api" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "cloud_logging_api" {
  project    = var.project_id
  service    = "logging.googleapis.com"
  depends_on = [google_project_service.cloud_resource_manager_api]
}

resource "google_logging_project_bucket_config" "vpcsc_denials" {
  provider         = google-beta
  project          = var.project_id
  location         = "global"
  retention_days   = 30
  bucket_id        = var.log_bucket_name
  enable_analytics = true
  depends_on       = [google_project_service.cloud_logging_api]
}

resource "google_logging_metric" "vpcsc_denials" {
  provider    = google-beta
  project     = var.project_id
  name        = var.log_based_metric_name
  filter      = <<EOT
  resource.type="audited_resource"
  severity>="ERROR"
  protoPayload.metadata."@type"="type.googleapis.com/google.cloud.audit.VpcServiceControlAuditMetadata"
  EOT
  bucket_name = "projects/${var.project_id}/locations/global/buckets/${var.log_bucket_name}"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key        = "service"
      value_type = "STRING"
    }
    labels {
      key        = "method"
      value_type = "STRING"
    }
    labels {
      key        = "perimeter"
      value_type = "STRING"
    }
    labels {
      key        = "identity"
      value_type = "STRING"
    }
    labels {
      key        = "dryRun"
      value_type = "BOOL"
    }
    labels {
      key        = "projectId"
      value_type = "STRING"
    }
  }
  label_extractors = {
    "service"   = "EXTRACT(protoPayload.serviceName)"
    "method"    = "EXTRACT(protoPayload.methodName)"
    "perimeter" = "EXTRACT(protoPayload.metadata.securityPolicyInfo.servicePerimeterName)"
    "identity"  = "EXTRACT(protoPayload.authenticationInfo.principalEmail)"
    "dryRun"    = "EXTRACT(protoPayload.metadata.dryRun)"
    "projectId" = "EXTRACT(resource.labels.project_id)"
  }
  depends_on = [google_logging_project_bucket_config.vpcsc_denials]
}

resource "google_logging_organization_sink" "vpcsc_denials" {
  provider         = google-beta
  name             = var.log_router_aggregated_sink_name
  org_id           = var.org_id
  destination      = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/${var.log_bucket_name}"
  filter           = <<EOT
  protoPayload.metadata.@type:"type.googleapis.com/google.cloud.audit.VpcServiceControlAuditMetadata"
  EOT
  include_children = true
  depends_on       = [google_logging_project_bucket_config.vpcsc_denials]
}

resource "google_project_iam_member" "logs_bucket_writer" {
  project    = var.project_id
  role       = "roles/logging.bucketWriter"
  member     = google_logging_organization_sink.vpcsc_denials.writer_identity
  depends_on = [google_logging_organization_sink.vpcsc_denials]
}
