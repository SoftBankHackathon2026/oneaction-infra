resource "google_managed_kafka_cluster" "this" {
  count      = var.enabled ? 1 : 0
  cluster_id = "${var.name}-review"
  location   = var.region
  labels     = var.labels
  capacity_config {
    vcpu_count   = var.vcpu_count
    memory_bytes = var.memory_gib * 1024 * 1024 * 1024
  }
  gcp_config {
    access_config {
      network_configs { subnet = var.subnet_id }
    }
  }
  rebalance_config { mode = "AUTO_REBALANCE_ON_SCALE_UP" }
}
output "contract" {
  value = {
    enabled    = var.enabled
    cluster_id = try(google_managed_kafka_cluster.this[0].cluster_id, null)
    # The documented SASL bootstrap endpoint uses the project ID, not number.
    bootstrap_brokers = var.enabled ? "bootstrap.${google_managed_kafka_cluster.this[0].cluster_id}.${var.region}.managedkafka.${var.project_id}.cloud.goog:9092" : null
    security_protocol = "SASL_SSL"
    sasl_mechanism    = "OAUTHBEARER"
    authentication    = "Application Default Credentials with automatic token refresh"
  }
}
