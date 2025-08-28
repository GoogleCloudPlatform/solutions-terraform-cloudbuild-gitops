variable "org_id" {
  type        = string
  description = "Org ID to deploy resources"
}

variable "project_id" {
  type        = string
  description = "Project ID to deploy resources"
}

variable "vpc_network" {
  type        = string
  description = "VPC network for IDS"
}

variable "subnetwork_region" {
  type        = string
  description = "Region for IPS Subnet"
  default     = "us-central1"
}

variable "vpc_subnet_ip" {
  type        = string
  description = "Subnet IP range"
}
