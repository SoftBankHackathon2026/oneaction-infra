data "google_project" "this" {
  count      = var.enabled ? 1 : 0
  project_id = var.project_id
}

locals {
  # Managed Kafka resolves Compute subnets by project number. Compute's
  # Terraform ID contains the project ID, so normalize the same-project path.
  subnet_id = var.enabled ? replace(var.subnet_id, "projects/${var.project_id}/", "projects/${data.google_project.this[0].number}/") : var.subnet_id
}

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
      network_configs { subnet = local.subnet_id }
    }
  }
  rebalance_config { mode = "AUTO_REBALANCE_ON_SCALE_UP" }
}
output "contract" {
  value = {
    enabled    = var.enabled
    cluster_id = try(google_managed_kafka_cluster.this[0].cluster_id, null)
    # Provider 7.29 does not expose bootstrapAddress. Never invent its format.
    bootstrap_brokers = var.enabled ? var.bootstrap_brokers : null
    security_protocol = "SASL_SSL"
    sasl_mechanism    = "OAUTHBEARER"
    authentication    = "Application Default Credentials with automatic token refresh"
  }
}
