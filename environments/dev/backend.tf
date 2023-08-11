terraform {

  backend "gcs" {
    bucket = "paloma-cicd-tfstate"
    prefix = "env/dev"
  }
  /*  
  backend "local" {
    path = "terraform.tfstate"
  }
  */
}
