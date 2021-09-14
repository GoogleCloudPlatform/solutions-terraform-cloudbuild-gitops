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


locals {
  env = "dev"
}

provider "google" {
  project = "${var.project}"
}



module "kubernetes_engine" {
	source = "./modules/kubernetes_engine"
	count = var.kubernetes_engine-create ? var.kubernetes_engine-count : 0
	k8s_cluster_name 		    = var.k8s_cluster_name
	k8s_cluster_location 	  = var.k8s_cluster_location
	k8s_remove_default_node_pool = var.k8s_remove_default_node_pool
	k8s_initial_node_count 	= var.k8s_initial_node_count
	k8s_username 			      = var.k8s_username
	k8s_password 			      = var.k8s_password
	k8s_issue_client_certificate = var.k8s_issue_client_certificate
	k8s_pool_name 			    = var.k8s_pool_name
	k8s_pool_location 		  = var.k8s_pool_location
	k8s_pool_node_count 	  = var.k8s_pool_node_count
	k8s_pool_preemptible 	  = var.k8s_pool_preemptible
	k8s_pool_machine_type 	= var.k8s_pool_machine_type
	k8s_pool_disable-legacy-endpoints = var.k8s_pool_disable-legacy-endpoints
	k8s_pool_oauth_scopes 	= var.k8s_pool_oauth_scopes
  project = "${var.project}"
  env     = "${local.env}"
}

