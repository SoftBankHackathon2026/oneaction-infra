# GKE's native Ingress controller owns the backend service, URL map and proxy.
# Terraform reserves the frontend and optional certificate; see render-platform.py.
resource "google_compute_global_address" "platform" {
  name = "${var.name}-platform"
}
resource "google_compute_managed_ssl_certificate" "platform" {
  count = var.domain_name == "" ? 0 : 1
  name  = "${var.name}-platform"
  managed { domains = [var.domain_name] }
}
output "address" { value = google_compute_global_address.platform.address }
output "contract" {
  value = {
    address          = google_compute_global_address.platform.address
    address_name     = google_compute_global_address.platform.name
    domain_name      = var.domain_name
    certificate_name = try(google_compute_managed_ssl_certificate.platform[0].name, null)
  }
}
