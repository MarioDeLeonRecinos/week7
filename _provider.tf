terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.26.0"
    }
  }
}

provider "google" {
  project     = "week7-354615"
}