provider "google" {
  project        = var.project_id
  region         = var.region
  default_labels = local.labels
}
locals {
  name   = "${var.name}-${var.environment}"
  labels = { project = var.name, owner = substr(replace(lower(var.owner), "/[^a-z0-9_-]/", "-"), 0, 63), env = var.environment, managed_by = "terraform" }
  zones  = [for suffix in sort(tolist(var.node_zone_suffixes)) : "${var.region}-${suffix}"]
  services = toset(concat([
    "compute.googleapis.com", "container.googleapis.com", "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com", "secretmanager.googleapis.com", "monitoring.googleapis.com",
    "logging.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com", "dns.googleapis.com"
  ], var.enable_kafka ? ["managedkafka.googleapis.com"] : []))
}
resource "google_project_service" "required" {
  for_each           = local.services
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "network" {
  source     = "./network"
  project_id = var.project_id
  region     = var.region
  name       = local.name
  labels     = local.labels
  depends_on = [google_project_service.required]
}

module "storage" {
  source     = "./storage"
  project_id = var.project_id
  region     = var.region
  name       = local.name
  labels     = local.labels
  depends_on = [google_project_service.required]
}

module "gke" {
  source              = "./gke"
  project_id          = var.project_id
  region              = var.region
  name                = local.name
  labels              = local.labels
  network_id          = module.network.network_id
  subnet_id           = module.network.gke_subnet_id
  zones               = local.zones
  machine_type        = var.node_machine_type
  node_count_per_zone = var.node_count_per_zone
  public_access_cidrs = var.public_access_cidrs
  admin_members       = var.admin_members
  deletion_protection = var.deletion_protection
  depends_on          = [google_project_service.required]
}

module "database" {
  enable_proxy_public_ip = var.db_enable_proxy_public_ip
  source                 = "./database"
  project_id             = var.project_id
  region                 = var.region
  name                   = local.name
  labels                 = local.labels
  network_id             = module.network.network_id
  service_connection_id  = module.network.service_connection_id
  tier                   = var.db_tier
  password               = var.db_password
  password_version       = var.db_password_version
  high_availability      = var.db_high_availability
  deletion_protection    = var.deletion_protection
  depends_on             = [google_project_service.required]
}

module "load_balancer" {
  source      = "./load-balancer"
  project_id  = var.project_id
  region      = var.region
  name        = local.name
  labels      = local.labels
  domain_name = var.domain_name
  depends_on  = [google_project_service.required]
}

module "dns" {
  source      = "./dns"
  project_id  = var.project_id
  region      = var.region
  name        = local.name
  labels      = local.labels
  domain_name = var.domain_name
  dns_domain  = var.dns_domain
  zone_name   = var.dns_zone_name
  address     = module.load_balancer.address
  depends_on  = [google_project_service.required]
}

module "kafka" {
  source            = "./kafka"
  project_id        = var.project_id
  region            = var.region
  name              = local.name
  labels            = local.labels
  enabled           = var.enable_kafka
  subnet_id         = module.network.data_subnet_id
  vcpu_count        = var.kafka_vcpu_count
  memory_gib        = var.kafka_memory_gib
  bootstrap_brokers = var.kafka_bootstrap_brokers
  depends_on        = [google_project_service.required]
}

module "secrets" {
  source        = "./secrets"
  project_id    = var.project_id
  region        = var.region
  name          = local.name
  labels        = local.labels
  review_bucket = module.storage.review_bucket_name
  enable_kafka  = var.enable_kafka
  workload_pool = module.gke.contract.workload_pool
  depends_on    = [google_project_service.required]
}

module "observability" {
  source             = "./observability"
  project_id         = var.project_id
  region             = var.region
  name               = local.name
  labels             = local.labels
  database_name      = module.database.instance_name
  logs_bucket        = module.storage.logs_bucket_name
  notification_email = var.notification_email
  depends_on         = [google_project_service.required]
}

module "tailscale" {
  count              = var.enable_tailscale && var.tailscale_auth_key_secret_id != "" ? 1 : 0
  source             = "./tailscale"
  project_id         = var.project_id
  name               = local.name
  labels             = local.labels
  zone               = local.zones[0]
  machine_type       = var.tailscale_machine_type
  network_id         = module.network.network_id
  subnet_id          = module.network.gke_subnet_id
  auth_key_secret_id = var.tailscale_auth_key_secret_id
  advertise_routes   = ["10.20.32.0/19", "10.20.10.0/24", "10.20.128.0/20"]
  # The private VM needs NAT for packages and the Tailscale control plane.
  depends_on = [module.network, google_project_service.required]
}
