mock_provider "google" {}

run "kafka_uses_project_number_in_subnet_path" {
  command = plan
  module { source = "./kafka" }
  override_data {
    target = data.google_project.this[0]
    values = { number = "123456789" }
  }
  variables {
    project_id        = "oneaction-test-123"
    region            = "asia-northeast3"
    name              = "oneaction-dev"
    labels            = { project = "oneaction" }
    enabled           = true
    subnet_id         = "projects/oneaction-test-123/regions/asia-northeast3/subnetworks/data"
    vcpu_count        = 4
    memory_gib        = 4
    bootstrap_brokers = "bootstrap-issued.example.cloud.goog:9092"
  }
  assert {
    condition     = one(one(one(google_managed_kafka_cluster.this[0].gcp_config).access_config).network_configs).subnet == "projects/123456789/regions/asia-northeast3/subnetworks/data"
    error_message = "Managed Kafka must receive the project-number form of the Compute subnet path."
  }
  assert {
    condition     = output.contract.bootstrap_brokers == "bootstrap-issued.example.cloud.goog:9092"
    error_message = "The deployment contract must preserve the actual queried bootstrap endpoint."
  }
}

run "kafka_does_not_invent_bootstrap_address" {
  command = plan
  module { source = "./kafka" }
  variables {
    project_id = "oneaction-test-123"
    region     = "asia-northeast3"
    name       = "oneaction-dev"
    labels     = {}
    enabled    = true
    subnet_id  = "projects/123456789/regions/asia-northeast3/subnetworks/data"
    vcpu_count = 4
    memory_gib = 4
  }
  assert {
    condition     = output.contract.bootstrap_brokers == null
    error_message = "Unknown bootstrap addresses must stay null, rather than use a legacy naming convention."
  }
}

run "private_compute" {
  command = plan
  module { source = "./gke" }
  variables {
    project_id          = "oneaction-test-123"
    region              = "asia-northeast3"
    name                = "oneaction-dev"
    labels              = { project = "oneaction", env = "dev" }
    network_id          = "projects/oneaction-test-123/global/networks/test"
    subnet_id           = "projects/oneaction-test-123/regions/asia-northeast3/subnetworks/test"
    zones               = ["asia-northeast3-a", "asia-northeast3-b", "asia-northeast3-c"]
    machine_type        = "e2-medium"
    node_count_per_zone = 1
    public_access_cidrs = ["203.0.113.10/32"]
    admin_members       = []
    deletion_protection = true
  }
  assert {
    condition     = google_container_cluster.this.private_cluster_config[0].enable_private_nodes && google_container_cluster.this.workload_identity_config[0].workload_pool == "oneaction-test-123.svc.id.goog"
    error_message = "Nodes must be private and workload identity enabled."
  }
  assert {
    condition     = google_container_node_pool.this.node_config[0].workload_metadata_config[0].mode == "GKE_METADATA" && google_container_node_pool.this.node_config[0].disk_size_gb == 20
    error_message = "Workloads must use GKE metadata and the AWS-equivalent 20 GiB node disks."
  }
  assert {
    condition     = google_container_cluster.this.addons_config[0].gce_persistent_disk_csi_driver_config[0].enabled
    error_message = "Persistent volumes need the managed GCE PD CSI driver."
  }
}

run "private_database" {
  command = plan
  module { source = "./database" }
  variables {
    project_id            = "oneaction-test-123"
    region                = "asia-northeast3"
    name                  = "oneaction-dev"
    labels                = { project = "oneaction" }
    network_id            = "projects/oneaction-test-123/global/networks/test"
    service_connection_id = "private-services-test"
    tier                  = "db-custom-1-3840"
    password              = "unit-test-only-not-a-real-password"
    password_version      = 2
    high_availability     = true
    deletion_protection   = true
  }
  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled == false && google_sql_database_instance.this.settings[0].ip_configuration[0].ssl_mode == "ENCRYPTED_ONLY"
    error_message = "Database must have no public IP and require encrypted connections."
  }
  assert {
    condition     = google_sql_database_instance.this.settings[0].availability_type == "REGIONAL" && google_sql_database_instance.this.settings[0].disk_autoresize_limit == 100
    error_message = "HA and the 100 GiB storage cap must reach the planned resource."
  }
  assert {
    condition     = google_sql_user.review.password == null && google_sql_user.review.password_wo_version == 2
    error_message = "The persisted password field must be empty; use the versioned write-only argument."
  }
  assert {
    condition     = contains([for flag in google_sql_database_instance.this.settings[0].database_flags : "${flag.name}=${flag.value}"], "cloudsql.logical_decoding=on")
    error_message = "The database must support logical change capture like the AWS source."
  }
}

run "least_privilege_secrets" {
  command = plan
  module { source = "./secrets" }
  variables {
    project_id    = "oneaction-test-123"
    region        = "asia-northeast3"
    name          = "oneaction-dev"
    labels        = { project = "oneaction" }
    workload_pool = "oneaction-test-123.svc.id.goog"
    review_bucket = "oneaction-test-review"
    enable_kafka  = false
  }
  assert {
    condition     = length(google_secret_manager_secret.this) == 3 && length(google_secret_manager_secret_iam_member.platform) == 3
    error_message = "The platform operator may read only the three named secrets."
  }
  assert {
    condition     = google_secret_manager_secret_iam_member.notifications.secret_id == google_secret_manager_secret.this["review_service"].secret_id && length(google_project_iam_member.kafka_client) == 0
    error_message = "Notifications may read only review-service; disabled Kafka must grant no client role."
  }
}

run "state_bucket" {
  command = plan
  module { source = "./bootstrap" }
  variables {
    project_id  = "oneaction-test-123"
    region      = "asia-northeast3"
    bucket_name = "oneaction-test-123-tfstate"
  }
  assert {
    condition     = google_storage_bucket.state.versioning[0].enabled && google_storage_bucket.state.uniform_bucket_level_access && google_storage_bucket.state.public_access_prevention == "enforced" && !google_storage_bucket.state.force_destroy
    error_message = "State must be versioned, private and protected from forced deletion."
  }
}

run "load_balancer_errors_are_monitored" {
  command = plan
  module { source = "./observability" }
  variables {
    project_id         = "oneaction-test-123"
    region             = "asia-northeast3"
    name               = "oneaction-dev"
    labels             = { project = "oneaction" }
    database_name      = "oneaction-dev-review"
    logs_bucket        = "oneaction-test-logs"
    notification_email = "platform@example.com"
  }
  assert {
    condition     = strcontains(google_monitoring_alert_policy.lb_5xx.conditions[0].condition_threshold[0].filter, "l7_lb_rule") && strcontains(google_logging_metric.lb_5xx.filter, "http_load_balancer")
    error_message = "Google uses different Logging and Monitoring resource types for load-balancer log metrics."
  }
  assert {
    condition     = google_monitoring_alert_policy.lb_5xx.conditions[0].condition_threshold[0].threshold_value == 0
    error_message = "The AWS ALB 5xx alarm needs a GCP load-balancer equivalent."
  }
  assert {
    condition     = strcontains(google_logging_metric.lb_5xx.filter, "jsonPayload.statusDetails!=\"response_sent_by_backend\"") && strcontains(google_monitoring_alert_policy.this["nat_drops"].conditions[0].condition_threshold[0].filter, "OUT_OF_RESOURCES")
    error_message = "Backend application errors and unrelated NAT drops must not be mislabeled as infrastructure failures."
  }
  assert {
    condition     = strcontains(google_monitoring_alert_policy.sql_free_storage.conditions[0].condition_prometheus_query_language[0].query, "database/disk/quota") && strcontains(google_monitoring_alert_policy.sql_free_storage.conditions[0].condition_prometheus_query_language[0].query, "database/disk/bytes_used") && strcontains(google_monitoring_alert_policy.sql_free_storage.conditions[0].condition_prometheus_query_language[0].query, "< 4294967296")
    error_message = "Free-storage warnings must preserve AWS's byte threshold after disk auto-resizing."
  }
}
