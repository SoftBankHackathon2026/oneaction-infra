variable "project_id" { type = string }
variable "name" { type = string }
variable "labels" { type = map(string) }
variable "zone" { type = string }
variable "machine_type" { type = string }
variable "network_id" { type = string }
variable "subnet_id" { type = string }
variable "auth_key_secret_id" {
  type = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,255}$", var.auth_key_secret_id))
    error_message = "Use an existing secret ID, never the key value or a cross-project path."
  }
}
variable "advertise_routes" {
  type = list(string)
  validation {
    condition     = length(var.advertise_routes) > 0 && alltrue([for route in var.advertise_routes : can(cidrnetmask(route)) && try(tonumber(split("/", route)[1]) >= 16, false)])
    error_message = "Advertise only explicit IPv4 subnets of /16 or narrower."
  }
}
