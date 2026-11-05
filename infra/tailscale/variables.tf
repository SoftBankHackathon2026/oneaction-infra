variable "aws_profile" {
  description = "AWS CLI profile, or empty when using exported temporary credentials."
  type        = string
  default     = ""
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-2"

  validation {
    condition     = var.aws_region == "ap-northeast-2"
    error_message = "The oneaction project uses the Seoul Region ap-northeast-2."
  }
}

variable "owner" {
  type    = string
  default = "hyeyeon.kim"
}

variable "instance_type" {
  description = "Subnet router instance. t4g.micro (1 GiB): on t4g.nano (512 MiB) the AL2023 `dnf install` in user_data is OOM-killed before tailscale is installed (seen 2026-11-05, i-0cd2d257bc10542fc)."
  type        = string
  default     = "t4g.micro"
}

variable "tailscale_auth_key_secret_arn" {
  description = <<-EOT
    Secrets Manager secret (plain string) holding a reusable, pre-authorized, tagged Tailscale auth key
    (tag:aws-subnet-router). The key is read on the instance at boot and never stored in Terraform state.
  EOT
  type        = string

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:ap-northeast-2:[0-9]{12}:secret:oneaction/tailscale-auth-key-[A-Za-z0-9]{6}$", var.tailscale_auth_key_secret_arn))
    error_message = "Expected the full ARN of oneaction/tailscale-auth-key in Seoul."
  }
}

variable "advertise_routes" {
  description = "CIDRs the router advertises into the tailnet. Default: the whole oneaction VPC."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "tailnet_routes" {
  description = <<-EOT
    VPC 에서 라우터를 거쳐 tailnet 으로 보낼 대역. EKS 의 플랫폼 수집기가 온프렘 kube API(172.30.1.10:6443)와
    워커·Connect NodePort 에 닿는 데 쓴다. GCP 라우터가 붙으면 10.20.32.0/19 등 GCP 대역을 더한다.
    빈 목록이면 기존처럼 tailnet → VPC 한 방향만 연다.
  EOT
  type        = list(string)
  default     = ["172.30.1.0/24"]

  validation {
    condition     = alltrue([for cidr in var.tailnet_routes : can(cidrnetmask(cidr)) && !startswith(cidr, "10.0.")])
    error_message = "Use IPv4 CIDRs outside the oneaction VPC (10.0.0.0/16)."
  }
}
