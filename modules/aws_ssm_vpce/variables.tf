variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = ""
}
variable "subnet_id" {
  description = "Subnet ID"
  type        = string
  default     = ""
}
variable "security_group_id" {
  description = "Security Group ID"
  type        = string
  default     = ""
}

variable "resource_name_prefix" {
  description = "prefix string attached to created resource name"
  type        = string
  default     = "test"
}