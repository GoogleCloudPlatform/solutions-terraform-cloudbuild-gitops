terraform {
  backend "gcs" {
    bucket = "strongsville-city-schools-tfstate"
    prefix = "env/dev"
  }
}
