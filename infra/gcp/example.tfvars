project_id          = "replace-with-project-id"
region              = "asia-northeast3"
environment         = "dev"
public_access_cidrs = ["203.0.113.10/32"] # Replace with your actual egress IP.
admin_members       = []                  # e.g. ["group:platform@example.com"]
# db_password is ephemeral: supply TF_VAR_db_password, never put it in this file.
# domain_name = "review.example.com"
# dns_domain = "example.com"
# dns_zone_name = "existing-public-zone"
# notification_email = "platform@example.com"
# enable_kafka = false
