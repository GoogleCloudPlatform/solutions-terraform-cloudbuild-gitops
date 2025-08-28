variable "project" {}
variable "function-name" {}
variable "function-desc" {}
variable "entry-point" {}

variable "env-vars" {
    default = null
    type = map
}

variable "secrets" {
    default = null
    type = list(object(
        {
            key = string
            id  = string
        }
    ))
}

variable "triggers" {
    default = null
    type = list(object(
        {
            event_type  = string
            resource    = string
        }
    ))
}

variable "region" {
  type        = string
  description = "Deployment region for the function"
  default     = "us-central1"
}

variable "invoker" {
  type        = string
  description = "Principal that can invoke the function"
  default     = null
}
