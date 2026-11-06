resource "google_storage_bucket" "review_docs" {
  name                        = "${var.project_id}-${var.name}-review"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = var.labels
  versioning { enabled = true }
}
resource "google_storage_bucket" "logs" {
  name                        = "${var.project_id}-${var.name}-logs"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = var.labels
  lifecycle_rule {
    condition { age = 30 }
    action { type = "Delete" }
  }
}
resource "google_storage_bucket_object" "prefixes" {
  for_each = toset(["rules/aws/", "rules/gcp/", "rules/local/", "rules/any/", "incidents/", "guides/"])
  name     = each.value
  bucket   = google_storage_bucket.review_docs.name
  content  = " "
}
output "review_bucket_name" { value = google_storage_bucket.review_docs.name }
output "logs_bucket_name" { value = google_storage_bucket.logs.name }
