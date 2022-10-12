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

variable "install_gpu_driver" {
  type      = bool
  default   = false
}
