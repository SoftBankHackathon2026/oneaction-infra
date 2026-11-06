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

variable "workload_pool" {
  type        = string
  description = "Created GKE workload identity pool; establishes cluster-before-IAM ordering."
}
