terraform {
  required_providers {
    google = {
      source = "hashicorp/google"

    }
  }

  backend "gcs" {
    bucket = "week7-354615"
    prefix = "terraform/state"
  }
}
provider "google" {
  version = "4.26.0"
  project = "week7-354615"
  region  = "us-west1"
  zone    = "us-west1-c"
}