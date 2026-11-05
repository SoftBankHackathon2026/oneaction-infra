variable "project_id" {
  type = string

}
variable "region" {
  type = string

}
variable "name" {
  type = string

}
variable "labels" {
  type = map(string)

}
variable "database_name" {
  type = string

}
variable "logs_bucket" {
  type = string

}
variable "notification_email" {
  type = string

}
variable "sql_free_storage_threshold_bytes" {
  description = "Counterpart of AWS FreeStorageSpace's byte threshold; independent of disk auto-resize."
  type        = number
  default     = 4294967296
  validation {
    condition     = var.sql_free_storage_threshold_bytes > 0 && floor(var.sql_free_storage_threshold_bytes) == var.sql_free_storage_threshold_bytes
    error_message = "Use a positive integer byte threshold."
  }
}
