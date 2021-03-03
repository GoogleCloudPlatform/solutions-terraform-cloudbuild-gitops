terraform {
  backend "gcs" {
    bucket = "infra-dev-tfstate"
    prefix = "terraform/state"
  }
}

# Updated

# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
