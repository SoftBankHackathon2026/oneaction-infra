mock_provider "google" {}

run "default_parity" {
  command = plan
  variables {
    project_id          = "oneaction-test-123"
    public_access_cidrs = ["203.0.113.10/32"]
    db_password         = "unit-test-only-not-a-real-password"
  }
  assert {
    condition     = output.platform.cloud == "gcp" && output.platform.region == "asia-northeast3"
    error_message = "GCP must default to Seoul and expose a cloud-neutral deployment contract."
  }
  assert {
    condition     = output.platform.cluster.total_node_count == 3
    error_message = "The default compute footprint must be three nodes."
  }
  assert {
    condition     = output.platform.database.public_ip_enabled == false && output.platform.database.ssl_mode == "ENCRYPTED_ONLY"
    error_message = "Database traffic must stay private and require encryption."
  }
  assert {
    condition     = output.platform.kafka.security_protocol == "SASL_SSL" && output.platform.kafka.sasl_mechanism == "OAUTHBEARER"
    error_message = "Managed Kafka must expose its actual authenticated TLS client contract."
  }
  assert {
    condition     = output.platform.load_balancer.domain_name == "" && output.platform.load_balancer.certificate_name == null
    error_message = "DNS/certificates must be optional until a real domain is supplied."
  }
}

run "tokyo_prod_without_kafka" {
  command = plan
  variables {
    project_id          = "oneaction-test-123"
    public_access_cidrs = ["203.0.113.10/32"]
    db_password         = "unit-test-only-not-a-real-password"
    region              = "asia-northeast1"
    environment         = "prod"
    enable_kafka        = false
  }
  assert {
    condition     = output.platform.name == "oneaction-prod" && output.platform.region == "asia-northeast1"
    error_message = "Project/environment settings must propagate without AWS resource references."
  }
  assert {
    condition     = output.platform.kafka.cluster_id == null && output.platform.kafka.bootstrap_brokers == null
    error_message = "Disabling Kafka must remove its endpoint and resources."
  }
  assert {
    condition     = !contains(keys(google_project_service.required), "managedkafka.googleapis.com")
    error_message = "Disabled Kafka must not enable the service."
  }
}

run "with_domain" {
  command = plan
  variables {
    project_id           = "oneaction-test-123"
    public_access_cidrs  = ["203.0.113.10/32"]
    db_password          = "unit-test-only-not-a-real-password"
    domain_name          = "review.example.com"
    dns_domain           = "example.com"
    notification_email   = "platform@example.com"
    db_high_availability = true
  }
  assert {
    condition     = output.platform.load_balancer.certificate_name == "oneaction-dev-platform"
    error_message = "A real domain must provision a GCP-managed frontend certificate."
  }
}

run "reject_world_open_admin" {
  command = plan
  variables {
    project_id          = "oneaction-test-123"
    public_access_cidrs = ["0.0.0.0/0"]
    db_password         = "unit-test-only-not-a-real-password"
  }
  expect_failures = [var.public_access_cidrs]
}
run "reject_empty_admin_allowlist" {
  command = plan
  variables {
    project_id          = "oneaction-test-123"
    public_access_cidrs = []
    db_password         = "unit-test-only-not-a-real-password"
  }
  expect_failures = [var.public_access_cidrs]
}
run "reject_weak_password" {
  command = plan
  variables {
    project_id          = "oneaction-test-123"
    public_access_cidrs = ["203.0.113.10/32"]
    db_password         = "short"
  }
  expect_failures = [var.db_password]
}
run "reject_invalid_project" {
  command = plan
  variables {
    project_id          = "YOUR_PROJECT_ID"
    public_access_cidrs = ["203.0.113.10/32"]
    db_password         = "unit-test-only-not-a-real-password"
  }
  expect_failures = [var.project_id]
}
run "reject_kafka_memory_ratio" {
  command = plan
  variables {
    project_id          = "oneaction-test-123"
    public_access_cidrs = ["203.0.113.10/32"]
    db_password         = "unit-test-only-not-a-real-password"
    kafka_vcpu_count    = 6
    kafka_memory_gib    = 3
  }
  expect_failures = [var.kafka_memory_gib]
}

run "identity_binding_depends_on_created_cluster_pool" {
  command = plan
  variables {
    project_id = "oneaction-test-123"
    public_access_cidrs = ["203.0.113.10/32"]
    db_password = "unit-test-only-not-a-real-password"
  }
  override_module {
    target = module.gke
    outputs = {
      contract = {
        name = "oneaction-dev"
        location = "asia-northeast3"
        workload_pool = "created-cluster-pool.svc.id.goog"
      }
    }
  }
  assert {
    condition = module.secrets.workload_pool == "created-cluster-pool.svc.id.goog"
    error_message = "Workload IAM bindings must consume the created cluster's pool output, not race its creation."
  }
}
