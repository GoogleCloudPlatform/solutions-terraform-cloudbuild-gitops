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

variable "container" {
  type = string
  default = "gcr.io/deeplearning-platform-release/tf2-gpu.2-10"
}

variable "tag" {
  type = string
  default = "latest"
}

