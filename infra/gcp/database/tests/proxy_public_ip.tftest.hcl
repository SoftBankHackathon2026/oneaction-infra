mock_provider "google" {}
variables {
  project_id            = "test-project"
  region                = "asia-northeast3"
  name                  = "test"
  labels                = {}
  network_id            = "projects/test-project/global/networks/test"
  service_connection_id = "test-connection"
  tier                  = "db-f1-micro"
  password              = "test-only-placeholder-password"
  password_version      = 1
  high_availability     = false
  deletion_protection   = true
}
run "private_default" {
  command = plan
  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "Default must remain private."
  }
}
run "proxy_opt_in" {
  command = plan
  variables { enable_proxy_public_ip = true }
  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled == true
    error_message = "Explicit proxy opt-in must retain a public address."
  }
  assert {
    condition     = length(google_sql_database_instance.this.settings[0].ip_configuration[0].authorized_networks) == 0
    error_message = "Proxy opt-in must not create direct-connect IP allowlists."
  }
  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ssl_mode == "ENCRYPTED_ONLY"
    error_message = "TLS must remain required."
  }
}
