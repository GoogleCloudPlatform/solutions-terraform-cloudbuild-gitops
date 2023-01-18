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


resource "google_storage_bucket" "bucket" {
  name     = "cf-source-bucket"
  location = "US"
}

resource "google_storage_bucket_object" "archive" {
  name   = "test-cf.zip"
  bucket = google_storage_bucket.bucket.name
  source = "${path.module}/CF_ZIPS/test-cf.zip"
}

resource "google_cloudfunctions_function" "function" {
  name        = "http-function-test"
  description = "Http trigger test function"
  runtime     = "python310"
  region      = "us-central1"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  trigger_http          = true
  entry_point           = "hello_world"
}

resource "google_cloudfunctions_function_iam_binding" "binding" {
  project = "baymanagement"
  region = "us-central1"
  cloud_function = "http-function-test"
  role = "roles/cloudfunctions.invoker"
  members = [
    "serviceAccount:baymanagement@appspot.gserviceaccount.com",
  ]
}