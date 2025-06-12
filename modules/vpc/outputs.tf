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

output "cluster_id" {
	value = google_container_cluster.primary.id
}

output "cluster_endpoint" {
	value = google_container_cluster.primary.endpoint
}

output "pool_id" {
	value = google_container_node_pool.primary_preemptible_nodes.id
}

output "pool_instance_group_urls" {
	value = google_container_node_pool.primary_preemptible_nodes.instance_group_urls
}
