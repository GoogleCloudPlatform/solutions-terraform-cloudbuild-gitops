variable "project" {}
variable "function-name" {}
variable "function-desc" {}
variable "entry-point" {}
variable "secrets" {
    type = list(object(
        {
            key = string
            id  = string
        }
    ))
    default = [
        {
            key = null
            id  = null
        }
    ]
}
