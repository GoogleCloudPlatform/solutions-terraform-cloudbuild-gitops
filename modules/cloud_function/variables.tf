variable "project" {}
variable "function-name" {}
variable "function-desc" {}
variable "entry-point" {}
variable "secret-id" {}
/*
variable "secret" {
    type = object({
        key = string
        id  = string
    })
    default = {
        key = null
        id  = null
    }
}
*/