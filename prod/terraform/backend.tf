terraform {
  backend "gcs" {
    bucket = "infra-dev-tfstate"
    prefix = "terraform/state"
  }
}

#Update

# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
