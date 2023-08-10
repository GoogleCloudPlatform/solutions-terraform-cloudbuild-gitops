# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "organization" {
  type          = string
  description   = "Google Cloud Organization ID"
}

variable "project" {
  type          = string
  description   = "Google Cloud Project ID"
}

variable "demo_project" {
  type          = string
  description   = "Google Cloud Project ID"
}

variable "region" {
  type          = string
}

variable "iap_user" {
  type          = string
  description   = "Users to allow access to IAP protected resources"
}

variable "create_dev_gke_cluster" {
  description   = "If set to true, it will create the dev gke cluster"
  type          = bool
  default       = false
}

variable "create_iap_run_sql_demo" {
  description   = "If set to true, it will create the iap_run_sql_demo"
  type          = bool
  default       = false
}

variable "create_ids_demo" {
  description   = "If set to true, it will create the cloud_ids"
  type          = bool
  default       = false
}

variable "recaptcha_site_key" {
  type          = string
  description   = "reCAPTCHA site key for Armor WAF Policy"
}
