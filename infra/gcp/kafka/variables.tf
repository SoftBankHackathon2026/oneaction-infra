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
variable "enabled" {
  type = bool

}
variable "subnet_id" {
  type = string

}
variable "vcpu_count" {
  type = number

}
variable "memory_gib" {
  type = number

}

variable "bootstrap_brokers" {
  description = "Actual bootstrapAddress from clusters describe, including port; null until queried after creation."
  type        = string
  default     = null
}
