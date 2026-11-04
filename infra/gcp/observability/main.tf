resource "google_logging_project_sink" "this" {
  name                   = "${var.name}-platform"
  destination            = "storage.googleapis.com/${var.logs_bucket}"
  unique_writer_identity = true
  filter                 = <<-FILTER
    (resource.type="k8s_container" AND resource.labels.cluster_name="${var.name}") OR
    (resource.type="cloudsql_database" AND resource.labels.database_id="${var.project_id}:${var.database_name}") OR
    (resource.type="nat_gateway" AND resource.labels.gateway_name="${var.name}-nat") OR
    (resource.type="http_load_balancer" AND resource.labels.url_map_name:"-platform-${var.name}-platform-") OR
    (resource.type="gce_subnetwork" AND (resource.labels.subnetwork_name="${var.name}-gke" OR resource.labels.subnetwork_name="${var.name}-data"))
  FILTER
}
resource "google_storage_bucket_iam_member" "log_writer" {
  bucket = var.logs_bucket
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.this.writer_identity
}
resource "google_monitoring_notification_channel" "email" {
  count        = var.notification_email == "" ? 0 : 1
  display_name = "${var.name} alerts"
  type         = "email"
  labels       = { email_address = var.notification_email }
}
locals {
  alerts = {
    sql_cpu = {
      filter    = "resource.type = \"cloudsql_database\" AND resource.labels.database_id = \"${var.project_id}:${var.database_name}\" AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""
      threshold = 0.8
      aligner   = "ALIGN_MEAN"
      duration  = "180s"
    }
    sql_disk = {
      filter    = "resource.type = \"cloudsql_database\" AND resource.labels.database_id = \"${var.project_id}:${var.database_name}\" AND metric.type = \"cloudsql.googleapis.com/database/disk/utilization\""
      threshold = 0.8
      aligner   = "ALIGN_MEAN"
      duration  = "180s"
    }
    nat_drops = {
      filter    = "resource.type = \"nat_gateway\" AND resource.labels.gateway_name = \"${var.name}-nat\" AND metric.type = \"router.googleapis.com/nat/dropped_sent_packets_count\""
      threshold = 0
      aligner   = "ALIGN_DELTA"
      duration  = "60s"
    }
  }
}
resource "google_monitoring_alert_policy" "this" {
  for_each              = local.alerts
  display_name          = "${var.name}-${each.key}"
  combiner              = "OR"
  notification_channels = google_monitoring_notification_channel.email[*].name
  conditions {
    display_name = each.key
    condition_threshold {
      filter          = each.value.filter
      comparison      = "COMPARISON_GT"
      threshold_value = each.value.threshold
      duration        = each.value.duration
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = each.value.aligner
      }
      trigger { count = 1 }
    }
  }
  alert_strategy { auto_close = "1800s" }
}
output "alert_policy_names" { value = concat([for policy in google_monitoring_alert_policy.this : policy.display_name], [google_monitoring_alert_policy.lb_5xx.display_name]) }

# The native GKE Ingress URL-map name contains namespace + Ingress name.
# BackendConfig enables request logging at sampleRate 1.0.
resource "google_logging_metric" "lb_5xx" {
  name   = "${var.name}-lb-5xx"
  filter = "resource.type=\"http_load_balancer\" AND resource.labels.url_map_name:\"-platform-${var.name}-platform-\" AND httpRequest.status>=500"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}
resource "google_monitoring_alert_policy" "lb_5xx" {
  display_name          = "${var.name}-lb-5xx"
  combiner              = "OR"
  notification_channels = google_monitoring_notification_channel.email[*].name
  conditions {
    display_name = "GKE Ingress server errors"
    condition_threshold {
      filter          = "resource.type = \"http_load_balancer\" AND metric.type = \"logging.googleapis.com/user/${google_logging_metric.lb_5xx.name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "60s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }
      trigger { count = 1 }
    }
  }
  alert_strategy { auto_close = "1800s" }
}
