resource "google_sql_database_instance" "this" {
  name                = "${var.name}-review"
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = var.deletion_protection
  settings {
    tier                        = var.tier
    edition                     = "ENTERPRISE"
    availability_type           = var.high_availability ? "REGIONAL" : "ZONAL"
    disk_size                   = 20
    disk_type                   = "PD_SSD"
    disk_autoresize             = true
    disk_autoresize_limit       = 100
    deletion_protection_enabled = var.deletion_protection
    user_labels                 = var.labels
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 1
      backup_retention_settings { retained_backups = 1 }
    }
    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }
    # Counterpart of the AWS rds.logical_replication parameter. Applied on
    # instance creation so CDC does not require an avoidable later restart.
    database_flags {
      name  = "cloudsql.logical_decoding"
      value = "on"
    }
  }
  lifecycle {
    precondition {
      condition     = var.service_connection_id != ""
      error_message = "Private services access must exist before Cloud SQL is created."
    }
  }
}
resource "google_sql_database" "review" {
  name     = "oneaction_review"
  instance = google_sql_database_instance.this.name
}
resource "google_sql_user" "review" {
  name                = "oneaction_admin"
  instance            = google_sql_database_instance.this.name
  password_wo         = var.password
  password_wo_version = var.password_version
}
output "instance_name" { value = google_sql_database_instance.this.name }
output "contract" {
  value = {
    name              = google_sql_database.review.name
    username          = google_sql_user.review.name
    connection_name   = google_sql_database_instance.this.connection_name
    private_ip        = google_sql_database_instance.this.private_ip_address
    public_ip_enabled = google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled
    ssl_mode          = google_sql_database_instance.this.settings[0].ip_configuration[0].ssl_mode
    proxy_host        = "127.0.0.1"
    proxy_port        = 5432
  }
}
