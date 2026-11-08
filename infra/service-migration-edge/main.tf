terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 5.100.0" }
  }
  backend "s3" { key = "dev/service-migration-edge/terraform.tfstate" }
}

provider "aws" {
  region              = "ap-northeast-2"
  allowed_account_ids = ["974402993422"]
}

variable "aws_alb_dns_name" {
  type        = string
  default     = null
  description = "GitOps service-migration-aws-active ALB hostname; null leaves DNS uncreated."
  validation {
    condition     = var.aws_alb_dns_name == null ? true : can(regex("^[a-zA-Z0-9.-]+\\.elb\\.amazonaws\\.com$", var.aws_alb_dns_name))
    error_message = "Use an ALB DNS hostname without URL, path, credentials, or IP."
  }
}

resource "aws_route53_record" "receipt" {
  count   = var.aws_alb_dns_name == null ? 0 : 1
  zone_id = "Z02519793E7CZENYZOJQN"
  name    = "service-migration.hackerthon.yubin.dev"
  type    = "CNAME"
  ttl     = 300
  records = [var.aws_alb_dns_name]
}

output "receipt_url" {
  value = "https://service-migration.hackerthon.yubin.dev"
}
