mock_provider "google" {}

run "reject_partial_full_scope" {
  command = plan
  variables {
    project_id          = "oneaction-test-123"
    public_access_cidrs = ["203.0.113.10/32"]
    db_password         = "unit-test-only-not-a-real-password"
    require_full_scope  = true
  }
  expect_failures = [var.require_full_scope]
}

run "router_needs_secret_reference" {
  command = plan
  variables {
    project_id                   = "oneaction-test-123"
    public_access_cidrs          = ["203.0.113.10/32"]
    db_password                  = "unit-test-only-not-a-real-password"
    enable_tailscale             = true
    tailscale_auth_key_secret_id = ""
  }
  expect_failures = [var.tailscale_auth_key_secret_id]
}

run "private_router" {
  command = plan
  module { source = "./tailscale" }
  variables {
    project_id         = "oneaction-test-123"
    name               = "abcdefghijklmnop-abcdef"
    labels             = { project = "oneaction" }
    zone               = "asia-northeast3-a"
    machine_type       = "e2-micro"
    network_id         = "projects/oneaction-test-123/global/networks/test"
    subnet_id          = "projects/oneaction-test-123/regions/asia-northeast3/subnetworks/test"
    auth_key_secret_id = "test-tailscale-key"
    advertise_routes   = ["10.20.32.0/19", "10.20.128.0/20"]
  }
  assert {
    condition     = google_compute_instance.router.can_ip_forward && length(google_compute_instance.router.network_interface[0].access_config) == 0
    error_message = "The router must forward private traffic without a public interface."
  }
  assert {
    condition     = google_compute_firewall.router_ingress.direction == "INGRESS" && one(google_compute_firewall.router_ingress.deny).protocol == "all"
    error_message = "The router may use outbound Tailscale connections only."
  }
  assert {
    condition     = strcontains(google_compute_instance.router.metadata_startup_script, "--auth-key=file:") && !strcontains(google_compute_instance.router.metadata_startup_script, "tskey-auth-")
    error_message = "Only a secret reference may enter instance metadata; the key must be read at runtime."
  }
  assert {
    condition     = google_secret_manager_secret_iam_member.auth_key.role == "roles/secretmanager.secretAccessor"
    error_message = "The router may read only its named secret."
  }
  assert {
    condition     = length(google_service_account.router.account_id) <= 30
    error_message = "Long environment names must not exceed Google's service-account ID limit."
  }
}
