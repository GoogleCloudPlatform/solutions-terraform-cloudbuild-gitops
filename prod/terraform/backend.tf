terraform {
  backend "gcs" {
    bucket = "infra-dev-tfstate"
    prefix = "terraform/prod/state"
  }
}

#Update

# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
