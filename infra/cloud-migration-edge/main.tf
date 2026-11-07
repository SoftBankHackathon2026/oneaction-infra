terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "= 5.100.0" }
    google = { source = "hashicorp/google", version = "~> 7.29.0" }
  }
  backend "s3" { key = "dev/cloud-migration-edge/terraform.tfstate" }
}
provider "aws" {
  region              = "ap-northeast-2"
  allowed_account_ids = ["974402993422"]
}
provider "google" {
  project = "ghost-project-513812"
  region  = "asia-northeast3"
}
variable "aws_alb_dns_name" {
  type        = string
  default     = null
  description = "GitOps가 만든 cloud-ingress ALB hostname. 생성 전 null이면 AWS DNS만 보류한다."
  validation {
    condition     = var.aws_alb_dns_name == null ? true : can(regex("^[a-zA-Z0-9.-]+\\.elb\\.amazonaws\\.com$", var.aws_alb_dns_name))
    error_message = "ALB DNS hostname만 입력한다 (URL/인증값 금지)."
  }
}
resource "google_compute_global_address" "gcp_app" {
  name         = "ghost-cloud-migration-app"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}
resource "aws_route53_record" "gcp_app" {
  zone_id = "Z02519793E7CZENYZOJQN"
  name    = "gcp-migration.hackerthon.yubin.dev"
  type    = "A"
  ttl     = 300
  records = [google_compute_global_address.gcp_app.address]
}
resource "aws_route53_record" "receipt" {
  count   = var.aws_alb_dns_name == null ? 0 : 1
  zone_id = "Z02519793E7CZENYZOJQN"
  name    = "cloud-migration.hackerthon.yubin.dev"
  type    = "CNAME"
  ttl     = 300
  records = [var.aws_alb_dns_name]
}
output "gcp_static_address" { value = google_compute_global_address.gcp_app.address }
output "receipt_url" { value = "https://cloud-migration.hackerthon.yubin.dev" }
output "gcp_app_url" { value = "https://gcp-migration.hackerthon.yubin.dev" }
