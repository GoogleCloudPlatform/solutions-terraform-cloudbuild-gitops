##  Copyright 2023 Google LLC
##  
##  Licensed under the Apache License, Version 2.0 (the "License");
##  you may not use this file except in compliance with the License.
##  You may obtain a copy of the License at
##  
##      https://www.apache.org/licenses/LICENSE-2.0
##  
##  Unless required by applicable law or agreed to in writing, software
##  distributed under the License is distributed on an "AS IS" BASIS,
##  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##  See the License for the specific language governing permissions and
##  limitations under the License.


##  This code creates PoC demo environment for Cloud IDS
##  This demo code is not built for production workload ##


output "_1_ids_victim_server_ip" {
  value = "IDS victim server ip - ${google_compute_instance.ids_victim_server.network_interface[0].network_ip}"
}

output "_2_ids_attacker_server" {
  value = "IDS attacker server ip - ${google_compute_instance.ids_attacker_machine.network_interface[0].network_ip}"
}

output "_3_ids_iap_ssh_attacker_server" {
  value = "gcloud compute ssh --zone ${var.network_zone} ${google_compute_instance.ids_attacker_machine.name}  --tunnel-through-iap --project ${var.demo_project_id}"
}

output "_4_ids_sample_attack_command" {
  value = "curl http://${google_compute_instance.ids_victim_server.network_interface[0].network_ip}/cgi-bin/../../../..//bin/cat%20/etc/passwd"
}