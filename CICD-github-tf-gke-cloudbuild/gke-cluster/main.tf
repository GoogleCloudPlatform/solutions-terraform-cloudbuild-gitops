/**
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


/******************************************
  GA Provider configuration
 *****************************************/
provider "google" {
project = "${var.project}"
}


/******************************************
  Provider backend store
  You must set the local application credentials using :
  gcloud auth application-default login
 *****************************************/
terraform {
  backend "gcs" {
    bucket      = "dataflow-bq-321500-tfstate"
    prefix      = "hello-cloudbuild"
  }
}

resource "google_container_cluster" "hello-cloudbuild" {
  name               = "hello-cloudbuild"
  location           = "us-central1"
  // network            = "var.network"
  initial_node_count = 1
}