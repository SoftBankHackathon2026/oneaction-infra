locals {
  secrets    = { database = "review-db", gitops = "gitops-token", review_service = "review-service" }
  identities = { eso = "eso", notifications = "argocd-eso", workload = "review" }
}
resource "google_secret_manager_secret" "this" {
  for_each  = local.secrets
  secret_id = "${substr(var.name, 0, 14)}-${substr(sha256(var.name), 0, 4)}-${each.value}"
  labels    = var.labels
  replication {
    auto {}
  }
}
resource "google_service_account" "this" {
  for_each   = local.identities
  account_id = "${substr(var.name, 0, 14)}-${substr(sha256(var.name), 0, 4)}-${each.value}"
}
resource "google_service_account_iam_member" "workload_identity" {
  for_each           = local.identities
  service_account_id = google_service_account.this[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.key == "workload" ? "platform/review-service" : each.key == "notifications" ? "external-secrets/external-secrets-argocd" : "external-secrets/external-secrets"}]"
}
resource "google_secret_manager_secret_iam_member" "platform" {
  for_each  = local.secrets
  secret_id = google_secret_manager_secret.this[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.this["eso"].email}"
}
resource "google_secret_manager_secret_iam_member" "notifications" {
  secret_id = google_secret_manager_secret.this["review_service"].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.this["notifications"].email}"
}
resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.this["workload"].email}"
}
resource "google_project_iam_member" "kafka_client" {
  count   = var.enable_kafka ? 1 : 0
  project = var.project_id
  role    = "roles/managedkafka.client"
  member  = "serviceAccount:${google_service_account.this["workload"].email}"
}
resource "google_storage_bucket_iam_member" "documents" {
  bucket = var.review_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.this["workload"].email}"
}
output "secret_ids" { value = { for key, secret in google_secret_manager_secret.this : key => secret.secret_id } }
output "identities" { value = { for key, identity in google_service_account.this : key => identity.email } }
