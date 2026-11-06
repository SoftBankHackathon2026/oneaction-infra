data "google_secret_manager_secret" "auth_key" {
  project   = var.project_id
  secret_id = var.auth_key_secret_id
}
resource "google_service_account" "router" {
  account_id   = "${substr(var.name, 0, 15)}-${substr(sha256(var.name), 0, 4)}-ts-router"
  display_name = "${var.name} private Tailscale router"
}
resource "google_secret_manager_secret_iam_member" "auth_key" {
  project   = var.project_id
  secret_id = data.google_secret_manager_secret.auth_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.router.email}"
}
resource "google_compute_firewall" "router_ingress" {
  name          = "${var.name}-ts-no-ingress"
  network       = var.network_id
  direction     = "INGRESS"
  priority      = 900
  target_tags   = ["${var.name}-ts-router"]
  source_ranges = ["0.0.0.0/0"]
  deny { protocol = "all" }
  log_config { metadata = "INCLUDE_ALL_METADATA" }
}
resource "google_compute_instance" "router" {
  name           = "${var.name}-ts-router"
  zone           = var.zone
  machine_type   = var.machine_type
  can_ip_forward = true
  labels         = var.labels
  tags           = ["${var.name}-ts-router"]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }
  network_interface {
    subnetwork = var.subnet_id
    # No access_config: no public address or directly exposed management port.
  }
  service_account {
    email  = google_service_account.router.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  metadata = { block-project-ssh-keys = "true", serial-port-enable = "false" }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  metadata_startup_script = templatefile("${path.module}/startup.sh.tftpl", {
    project_id = var.project_id
    secret_id  = var.auth_key_secret_id
    hostname   = "${var.name}-gcp-router"
    routes     = join(",", var.advertise_routes)
  })
  depends_on = [google_secret_manager_secret_iam_member.auth_key, google_compute_firewall.router_ingress]
}
output "contract" {
  value = {
    name                = google_compute_instance.router.name
    zone                = var.zone
    private_ip          = google_compute_instance.router.network_interface[0].network_ip
    advertised_routes   = var.advertise_routes
    route_approval      = "REQUIRED_IN_TAILSCALE_ADMIN"
    service_account     = google_service_account.router.email
    auth_key_secret_ref = data.google_secret_manager_secret.auth_key.id
  }
}
