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

variable "project" {
  type    = string
}

variable "machinetype" {
  type    = string
  default = "n1-standard-8"
}

variable "osimage" {
  type = string
}

variable "environment" {
  type = string
}

variable "instancerole" {
  type    = string
  default = "p"
}

variable "function" {
  type    = string
  default = "pdc"
}

variable "instancenumber" {
  type    = string
  default = "01"
}

variable "regionandzone" {
  type = string
}

variable "deployment-name" {
  type    = string
  default = ""
}

variable "assignedsubnet" {
  type    = string
  default = "default"
}

variable "domain-name" {
  type    = string
  default = "test-domain"
}

variable "kms-key" {
  type    = string
  default = "p@ssword"
}

variable "kms-region" {
  type    = string
  default = "us-central1"
}

variable "gcs-prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet-name" {
  type = string
}

variable "secondary-subnet-name" {
  type = string
}

variable "netbios-name" {
  type = string
}

variable "runtime-config" {
  type = string
}

variable "keyring" {
  type = string
}

variable "wait-on" {
  type = string
}

variable "status-variable-path" {
  type = string
}

variable "network-tag" {
  type        = list(string)
  default     = [""]
  description = "network tags"
}

variable "network-ip" {
  type    = string
  default = ""
}

#variable "project-id" {
#    type=string
#}
