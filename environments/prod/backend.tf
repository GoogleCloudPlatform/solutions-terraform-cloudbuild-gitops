terraform {
  backend "gcs" {
    bucket = "rj-test-341318-tfstate"
    prefix = "env/prod"
  }
}
