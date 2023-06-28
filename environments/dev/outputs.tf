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
/*
output "external_ip" {
  value = "${module.load_balancer.external_ip}"
}

output "dev_cluster_name" {
  value = "${module.gke_cluster.name}"
}
*/

output "_1_ids_victim_server_ip" {
  value = module.cloud_ids._1_ids_victim_server_ip
}

output "_2_ids_attacker_server" {
  value = module.cloud_ids._2_ids_attacker_server
}

output "_3_ids_iap_ssh_attacker_server" {
  value = module.cloud_ids._3_ids_iap_ssh_attacker_server
}

output "_4_ids_sample_attack_command" {
  value = module.cloud_ids._4_ids_sample_attack_command
}
