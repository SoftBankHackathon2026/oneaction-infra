resource "google_service_account" "nodes" {
  account_id   = "${var.name}-nodes"
  display_name = "${var.name} GKE nodes"
}
resource "google_project_iam_member" "nodes" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}
resource "google_project_iam_member" "admins" {
  for_each = var.admin_members
  project  = var.project_id
  role     = "roles/container.admin"
  member   = each.value
}
resource "google_container_cluster" "this" {
  name                     = var.name
  location                 = var.region
  node_locations           = var.zones
  network                  = var.network_id
  subnetwork               = var.subnet_id
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = var.deletion_protection
  resource_labels          = var.labels
  release_channel { channel = "REGULAR" }
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.20.0.0/28"
  }
  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled = false
    dynamic "cidr_blocks" {
      for_each = var.public_access_cidrs
      content {
        cidr_block   = cidr_blocks.value
        display_name = "approved-admin"
      }
    }
  }
  workload_identity_config { workload_pool = "${var.project_id}.svc.id.goog" }
  addons_config {
    http_load_balancing { disabled = false }
    gce_persistent_disk_csi_driver_config { enabled = true }
    gcp_filestore_csi_driver_config { enabled = false }
  }
  logging_config { enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS", "APISERVER", "SCHEDULER", "CONTROLLER_MANAGER"] }
  monitoring_config { enable_components = ["SYSTEM_COMPONENTS"] }
  enable_shielded_nodes = true
  networking_mode       = "VPC_NATIVE"
  datapath_provider     = "ADVANCED_DATAPATH"
  # The temporary default pool uses the dedicated identity too.
  node_config {
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  depends_on = [google_project_iam_member.nodes]
}
resource "google_container_node_pool" "this" {
  name           = "${var.name}-general"
  location       = var.region
  cluster        = google_container_cluster.this.name
  node_locations = var.zones
  node_count     = var.node_count_per_zone
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = 20
    disk_type       = "pd-balanced"
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = var.labels
    metadata        = { disable-legacy-endpoints = "true" }
    workload_metadata_config { mode = "GKE_METADATA" }
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
output "contract" {
  value = {
    name                = google_container_cluster.this.name
    location            = google_container_cluster.this.location
    total_node_count    = google_container_node_pool.this.node_count * length(var.zones)
    public_access_cidrs = var.public_access_cidrs
    workload_pool       = google_container_cluster.this.workload_identity_config[0].workload_pool
  }
}
