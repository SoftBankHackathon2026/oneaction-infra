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
variable "subnet_id" {
  type = string

}
variable "zones" {
  type = list(string)

}
variable "machine_type" {
  type = string

}
variable "node_count_per_zone" {
  type = number

}
variable "public_access_cidrs" {
  type = set(string)

}
variable "admin_members" {
  type = set(string)

}
variable "deletion_protection" {
  type = bool

}
