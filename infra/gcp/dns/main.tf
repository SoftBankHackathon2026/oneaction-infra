locals {
  enabled     = var.domain_name != ""
  create_zone = local.enabled && var.zone_name == ""
  domain      = var.dns_domain == "" ? var.domain_name : var.dns_domain
}
resource "google_dns_managed_zone" "this" {
  count      = local.create_zone ? 1 : 0
  name       = "${var.name}-public"
  dns_name   = "${local.domain}."
  labels     = var.labels
  visibility = "public"
  cloud_logging_config { enable_logging = true }
}
data "google_dns_managed_zone" "existing" {
  count = local.enabled && !local.create_zone ? 1 : 0
  name  = var.zone_name
}
locals {
  zone_name   = local.create_zone ? google_dns_managed_zone.this[0].name : try(data.google_dns_managed_zone.existing[0].name, null)
  zone_domain = local.create_zone ? google_dns_managed_zone.this[0].dns_name : try(data.google_dns_managed_zone.existing[0].dns_name, "")
}
resource "google_dns_record_set" "platform" {
  count        = local.enabled ? 1 : 0
  name         = "${var.domain_name}."
  managed_zone = local.zone_name
  type         = "A"
  ttl          = 300
  rrdatas      = [var.address]
  lifecycle {
    precondition {
      condition     = "${var.domain_name}." == local.zone_domain || endswith("${var.domain_name}.", ".${local.zone_domain}")
      error_message = "The application hostname must be inside the selected public DNS zone."
    }
  }
}
resource "google_dns_record_set" "caa" {
  count        = local.enabled ? 1 : 0
  name         = "${var.domain_name}."
  managed_zone = local.zone_name
  type         = "CAA"
  ttl          = 300
  rrdatas      = ["0 issue \"pki.goog\"", "0 issue \"letsencrypt.org\""]
}
output "name_servers" { value = local.create_zone ? google_dns_managed_zone.this[0].name_servers : [] }
