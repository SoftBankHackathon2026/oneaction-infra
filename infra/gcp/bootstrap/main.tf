terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 7.29.0" }
  }
}
variable "project_id" { type = string }
variable "bucket_name" { type = string }
variable "region" {
  type    = string
  default = "asia-northeast3"
}
provider "google" {
  project = var.project_id
  region  = var.region
}
resource "google_project_service" "storage" {
  project            = var.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}
resource "google_storage_bucket" "state" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  versioning { enabled = true }
  lifecycle { prevent_destroy = true }
  depends_on = [google_project_service.storage]
}
output "bucket_name" { value = google_storage_bucket.state.name }
