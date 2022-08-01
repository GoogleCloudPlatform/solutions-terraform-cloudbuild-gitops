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
