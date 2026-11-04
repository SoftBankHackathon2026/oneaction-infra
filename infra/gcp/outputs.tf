output "platform" {
  description = "Non-secret deployment contract. Feed terraform output -json platform to scripts/render-platform.py."
  value = {
    cloud            = "gcp"
    project_id       = var.project_id
    region           = var.region
    name             = local.name
    environment      = var.environment
    cluster          = module.gke.contract
    network          = { id = module.network.network_id, gke_subnet_id = module.network.gke_subnet_id, data_subnet_id = module.network.data_subnet_id }
    database         = module.database.contract
    storage          = { review_bucket = module.storage.review_bucket_name, logs_bucket = module.storage.logs_bucket_name }
    load_balancer    = module.load_balancer.contract
    kafka            = module.kafka.contract
    secrets          = module.secrets.secret_ids
    identities       = module.secrets.identities
    dns_name_servers = module.dns.name_servers
    alert_policies   = module.observability.alert_policy_names
  }
}
