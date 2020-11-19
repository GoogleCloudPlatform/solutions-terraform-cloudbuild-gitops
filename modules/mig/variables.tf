variable "project" {}
variable "env" {}
variable "region" {}
variable "sa_email" {}

variable "mig_region" {
  type = list
  default = ["europe-west1-b", "europe-west1-c", "europe-west1-d"]
 }