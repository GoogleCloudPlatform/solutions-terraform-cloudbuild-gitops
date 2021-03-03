terraform {
  backend "gcs" {
    bucket = "infra-dev-tfstate"
    prefix = "terraform/state"
  }
}

# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
