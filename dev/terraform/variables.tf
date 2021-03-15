# Following are the default values for creation of a resource in google cloud.
# These values can be updated directly here Or 
# you can use file terraform.tfvars to overide the default values 

# project id
variable "project_id" {
  type = string
  default = "som-rit-infrastructure-dev"
}

# vpc network name
variable "vpc_network_name" {
  type = string
  default = "infrastructure-dev-network-dev-mar15"
}
