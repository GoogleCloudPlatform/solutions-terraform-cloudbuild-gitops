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
variable "network-name" {
    type = "string" 
    default = "custom-network" 
}
variable "primary-cidr" {
    type = "string" 
    default = "10.10.1.0/16" 
}
variable "second-cidr" {
    type = "string" 
    default = "10.11.1.0/16" 
}
variable "third-cidr" {
    type = "string" 
    default = "10.12.1.0/16" 
}
variable "fourth-cidr" {
    type = "string" 
    default = "10.13.1.0/16" 
}
variable "deployment-name" {
    type = "string" 
    default = "depl" 
}
variable "primary-region" {
    type = "string" 
    default = "us-central1" 
}
variable "dr-region" {
    type = "string" 
    default = "us-east1" 
}
