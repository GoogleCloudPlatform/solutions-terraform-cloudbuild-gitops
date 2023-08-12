terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
  required_version = ">= 1.3.0"
}

/* Googleの認証はサービスアカウントキーではなく
   gcloud auth application-default loginで実施する */
provider "google" {
  #credentials   = file(var.gcp_credential_filename)
  project = var.gcp_project_hub
  region  = "asia-northeast1"
  zone    = "asia-northeast1-a"
}

provider "google" {
  alias = "spoke"

  #credentials   = file(var.gcp_credential_filename)
  project = var.gcp_project_spoke
  region  = "asia-northeast1"
  zone    = "asia-northeast1-a"
}

/* AWSの認証はIAMクレデンシャル */
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "ap-northeast-1"
}
