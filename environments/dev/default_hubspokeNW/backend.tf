terraform {
  /*
    backend "gcs" {
        bucket = "kh-paloma-m01-01-bucket-tfstate"
        prefix = "terraform/state/common"
    }
    */
  backend "local" {
    path = "terraform.tfstate"
  }
}
