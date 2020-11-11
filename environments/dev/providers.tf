terraform {
	required_providers {
		google = {
			source = "hashicorp/google"
		}
	}
}

provider "google" {
	//credentials = file(var.credentials)

	project = var.project
	//region  = var.region
	//zone    = var.zone
}

