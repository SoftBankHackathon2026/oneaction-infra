resource "google_compute_network" "this" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}
resource "google_compute_subnetwork" "gke" {
  name                     = "${var.name}-gke"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = "10.20.32.0/19"
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.24.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.28.0.0/20"
  }
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
resource "google_compute_subnetwork" "data" {
  name                     = "${var.name}-data"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = "10.20.10.0/24"
  private_ip_google_access = true
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
resource "google_compute_router" "this" {
  name    = "${var.name}-router"
  network = google_compute_network.this.id
  region  = var.region
}
resource "google_compute_router_nat" "this" {
  name                               = "${var.name}-nat"
  router                             = google_compute_router.this.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
resource "google_compute_global_address" "private_services" {
  name          = "${var.name}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.20.128.0"
  prefix_length = 20
  network       = google_compute_network.this.id
}
resource "google_service_networking_connection" "this" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
  deletion_policy         = "ABANDON"
}
output "network_id" { value = google_compute_network.this.id }
output "gke_subnet_id" { value = google_compute_subnetwork.gke.id }
output "data_subnet_id" { value = google_compute_subnetwork.data.id }
output "service_connection_id" { value = google_service_networking_connection.this.id }
output "nat_name" { value = google_compute_router_nat.this.name }
