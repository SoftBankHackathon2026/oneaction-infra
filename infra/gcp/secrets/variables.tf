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
variable "review_bucket" {
  type = string

}
variable "enable_kafka" {
  type = bool

}
