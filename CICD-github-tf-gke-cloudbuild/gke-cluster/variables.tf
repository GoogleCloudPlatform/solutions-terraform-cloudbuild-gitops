/**
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "project" {
  description = "The project ID to deploy to"
  default     =  "dataflow-bq-321500"
}

variable "credentials_path" {
  description = "The path to a Google Cloud Service Account credentials file"
  default = "sa-key.json"
}

variable "region" {
  description = "The region to deploy to"
  default     = "us-central1"
}

variable "zone" {
  description = "The zone to deploy to"
  default     = "us-central1-a"
}
variable "network" {
  description = "The GCP network to launch the instance in"
  default     = "projects/dataflow-bq-321500/global/networks/default"
}

variable "subnetwork" {
  description = "The GCP subnetwork to launch the instance in"
  default     = "projects/dataflow-bq-321500/regions/us-central1/subnetworks/default"
}
variable "terraform_service_account" {
  description = "The GCP subnetwork to launch the instance in"
  default     = "terraform@dataflow-bq-321500.iam.gserviceaccount.com"
}