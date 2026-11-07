provider "aws" {
  profile             = var.aws_profile == "" ? null : var.aws_profile
  region              = var.aws_region
  allowed_account_ids = ["974402993422"]

  default_tags {
    tags = {
      Project = "oneaction"
      Owner   = var.owner
      Env     = "dev"
    }
  }
}

data "aws_partition" "current" {}

locals {
  cluster_name = "oneaction"
  remote_state_config = {
    bucket         = "oneaction-tfstate-974402993422"
    region         = var.aws_region
    dynamodb_table = "oneaction-terraform-locks"
    encrypt        = true
  }
  node_tags = {
    Name    = "${local.cluster_name}-eks-node"
    Project = "oneaction"
    Owner   = var.owner
    Env     = "dev"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config  = merge(local.remote_state_config, { key = "dev/network/terraform.tfstate" })
}

data "terraform_remote_state" "observability" {
  backend = "s3"
  config  = merge(local.remote_state_config, { key = "dev/observability/terraform.tfstate" })
}

# 도쿄 플랫폼 서버(oneport-platform 스택)의 고정 IP. 수집기가 EKS 공개 엔드포인트로 읽으므로 허용 목록에 더한다.
# 그 스택 상태가 없으면 빈 목록이다.
data "terraform_remote_state" "oneport_platform" {
  backend  = "s3"
  config   = merge(local.remote_state_config, { key = "dev/oneport-platform/terraform.tfstate" })
  defaults = { eks_public_access_cidrs = [] }
}

data "aws_subnet" "eks" {
  for_each = toset(data.terraform_remote_state.network.outputs.private_eks_subnet_ids)
  id       = each.value
}

data "aws_security_group" "node_extra" {
  id = data.terraform_remote_state.network.outputs.eks_node_extra_security_group_id
}

# Verify the observability-owned group exists; do not import or recreate it here.
data "aws_cloudwatch_log_group" "eks" {
  name = data.terraform_remote_state.observability.outputs.eks_log_group_name
}
