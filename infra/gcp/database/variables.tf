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
variable "network_id" {
  type = string

}
variable "service_connection_id" {
  type = string

}
variable "tier" {
  type = string

}
variable "password" {
  type      = string
  sensitive = true
  ephemeral = true
}
variable "password_version" {
  type = number

}
variable "high_availability" {
  type = bool

}
variable "deletion_protection" {
  type = bool

}

variable "enable_proxy_public_ip" {
  type        = bool
  default     = false
  description = "Enable public address for authenticated Cloud SQL Auth Proxy from AWS; no authorized_networks are added."
}
