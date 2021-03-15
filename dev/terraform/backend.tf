terraform {
  backend "gcs" {
    bucket = "infra-dev-tfstate"
    prefix = "terraform/dev/state"
  }
}

# Updated

# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
