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


resource "google_storage_bucket" "cap-archive-mds" {
  name          = "cap-archive-mds-${var.env}"
  location      = "${var.region}"
  force_destroy = true

  lifecycle_rule {
    condition {
      age = "7"
    }
    action {
      type = "Delete"
    }
  }
}

#data "local_file" "startup_script" {
#    filename = "${path.module}/files/cap-template-ss.sh"
#}

resource "google_storage_bucket_object" "mig-sftp-ss" {
  name   = "cap-template-ss.sh"
  content = file("${path.module}/files/cap-template-ss.sh")
  bucket = "${google_storage_bucket.cap-archive-mds.name}"
}