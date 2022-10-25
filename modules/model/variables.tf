variable "project" {}

variable "model_name" {
  type      = string
  nullable  = false
}

variable "pipeline_endpoint" {
  type = string
}

variable "pipeline_bucket" {
  type = string
}

# By default executes on day that doesnt exist, i.e never
variable "cron_schedule" {
  type = string
  default = "0 0 5 31 2 ?"
}

# TODO: Specify hardware for default_pipeline.py here. Pass as runtime parameters
variable "machine_type" {
  type      = string
  default   = "n1-standard-1"
}

variable "gpu_count" {
  type      = number
  default   = 0
}

variable "gpu_type" {
  type = string
  default = "NVIDIA_TESLA_T4"
}
# TODO END

