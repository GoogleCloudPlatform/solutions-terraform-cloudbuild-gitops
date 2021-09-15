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
#**********


resource "google_container_cluster" "primary" {
  name     = var.k8s_cluster_name
  location = var.k8s_cluster_location
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = var.k8s_remove_default_node_pool
  initial_node_count       = var.k8s_initial_node_count
 
  master_auth {
 

    client_certificate_config {
      issue_client_certificate = var.k8s_issue_client_certificate
    }
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = var.k8s_pool_name
  location   = var.k8s_pool_location
  cluster    = google_container_cluster.primary.name
  node_count = var.k8s_pool_node_count
  node_config {
    preemptible  = var.k8s_pool_preemptible
    machine_type = var.k8s_pool_machine_type
    metadata = {
      disable-legacy-endpoints = var.k8s_pool_disable-legacy-endpoints
    }
    oauth_scopes = var.k8s_pool_oauth_scopes
  }
}
