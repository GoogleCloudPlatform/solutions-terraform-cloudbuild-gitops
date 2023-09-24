/* GCP用変数 */
/*
variable "gcp_credential_filename" {
  type    = string
  default = "./gcp_credentioal.json"
}
*/
variable "gcp_project_hub" {
  type    = string
  default = "kh-paloma-m01-01"
}
variable "gcp_project_spoke" {
  type    = string
  default = "kh-paloma-m01-02"
}
variable "is_create_gcp_instance" {
  type    = number
  default = 0
}
variable "is_create_aws_instance" {
  type    = number
  default = 0
}
variable "is_create_vpn_with_aws" {
  type    = number
  default = 0
}

/* AWS用変数 */
/* AWS用変数 */
variable "aws_access_key" {
  type    = string
  default = "NONE"
}
variable "aws_secret_key" {
  type    = string
  default = "NONE"
}
variable "aws_resname_prefix" {
  type    = string
  default = "paloma-dv-"
}
