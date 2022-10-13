variable "project" {}

variable "model_name" {
  type      = string
  nullable  = false
}

variable "machine_type" {
  type      = string
  default   = "n1-standard-1"
}

variable "instance_owners" {
  type      = list(string)
  default   = ["olav@olavnymoen.com"]
}

variable "gpu_count" {
  type      = number
  default   = 0
}

variable "gpu_type" {
  type = string
  default = "NVIDIA_TESLA_T4"
}

variable "pipeline_endpoint" {
  type = string
}

variable "pipeline_bucket" {
  type = string
}
