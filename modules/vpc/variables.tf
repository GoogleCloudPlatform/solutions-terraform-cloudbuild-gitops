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


variable "project" {}
variable "env" {}
variable "k8s_cluster_name" {
	type = string
}

variable "k8s_cluster_location" {
	type = string
}

variable "k8s_remove_default_node_pool" {
	type = bool
}

variable "k8s_initial_node_count" {
	type = number
}

variable "k8s_issue_client_certificate" {
	type = bool
}

variable "k8s_pool_name" {
	type = string
}

variable "k8s_pool_location" {
	type = string
	default = "us-central1-a"
}

variable "k8s_pool_node_count" {
	type = number
}

variable "k8s_pool_preemptible" {
	type = bool
}

variable "k8s_pool_machine_type" {
	type = string
}


variable "k8s_pool_disable-legacy-endpoints" {
	type = bool
}

variable "k8s_min_node_count" {
	type = number
}
variable "k8s_max_node_count" {
    type = number
}

variable "k8s_pool_oauth_scopes" {
	type = list(string)
}
