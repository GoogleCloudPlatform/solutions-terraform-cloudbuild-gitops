#
#  Copyright 2019 Google Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
output "subnet-name" {
  value = "${google_compute_subnetwork.primary-subnetwork.name}"
  #value = "test-string"
}
output "second-subnet-name" {
  value = "${google_compute_subnetwork.subnetwork-2.name}"
  #value = "test-string"
}
output "third-subnet-name" {
  value = "${google_compute_subnetwork.subnetwork-3.name}"
  #value = "test-string"
}
output "fourth-subnet-name" {
  value = "${google_compute_subnetwork.subnetwork-4.name}"
  #value = "test-string"
}
