mock_provider "google" {}

run "default_parity" {
  command = plan
  variables {
    project_id = "oneaction-test-123"
    public_access_cidrs = ["203.0.113.10/32"]
    db_password = "unit-test-only-not-a-real-password"
  }
  assert {
    condition = output.platform.cloud == "gcp" && output.platform.region == "asia-northeast3"
    error_message = "GCP must default to Seoul and expose a cloud-neutral deployment contract."
  }
  assert {
    condition = output.platform.cluster.total_node_count == 3
    error_message = "The default compute footprint must be three nodes."
  }
  assert {
    condition = output.platform.database.public_ip_enabled == false && output.platform.database.ssl_mode == "ENCRYPTED_ONLY"
    error_message = "Database traffic must stay private and require encryption."
  }
  assert {
    condition = output.platform.kafka.security_protocol == "SASL_SSL" && output.platform.kafka.sasl_mechanism == "OAUTHBEARER"
    error_message = "Managed Kafka must expose its actual authenticated TLS client contract."
  }
  assert {
    condition = output.platform.load_balancer.domain_name == "" && output.platform.load_balancer.certificate_name == null
    error_message = "DNS/certificates must be optional until a real domain is supplied."
  }
}
