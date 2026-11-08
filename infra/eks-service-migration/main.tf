# AWS 접수서비스(service-migration namespace)의 인증값 공급 경로.
# Secrets Manager 비밀 1개(메타데이터만), 그 비밀과 기존 sample-app 비밀을 읽는 IAM 역할,
# external-secrets namespace 의 전용 ServiceAccount 에 Pod Identity 로 연결한다.
# 비밀 값은 Terraform 에 넣지 않는다. `aws secretsmanager put-secret-value` 로 따로 공급한다.
terraform {
  required_version = ">= 1.5.7, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 5.100.0" }
  }
  backend "s3" { key = "dev/eks-service-migration/terraform.tfstate" }
}

provider "aws" {
  region              = "ap-northeast-2"
  allowed_account_ids = ["974402993422"]
  default_tags { tags = { Project = "oneaction", Owner = "gayeon.won", Env = "dev" } }
}

# JSON 속성: api_token (receipt /api 와 온프렘 forward 공용), control_token (/control 전용).
resource "aws_secretsmanager_secret" "receipt" {
  name                    = "oneaction/service-migration"
  description             = "AWS receipt service API token and control token for the full-service migration"
  recovery_window_in_days = 30
  lifecycle { prevent_destroy = true }
}

# app-token 은 EKS 앱의 기존 요청 API 토큰과 같아야 한다. 복사하지 않고 같은 비밀의 속성을 읽는다.
data "aws_secretsmanager_secret" "sample_app" {
  name = "oneaction/sample-app"
}

resource "aws_iam_role" "eso" {
  name                 = "ghost-oneaction-external-secrets-service-migration"
  permissions_boundary = "arn:aws:iam::974402993422:policy/GhostWorkloadBoundary"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = { StringEquals = {
        "aws:RequestTag/eks-cluster-arn"            = "arn:aws:eks:ap-northeast-2:974402993422:cluster/oneaction"
        "aws:RequestTag/kubernetes-namespace"       = "external-secrets"
        "aws:RequestTag/kubernetes-service-account" = "external-secrets-service-migration"
      } }
    }]
  })
}

resource "aws_iam_role_policy" "read_secrets" {
  name = "read-service-migration-secrets"
  role = aws_iam_role.eso.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource  = [aws_secretsmanager_secret.receipt.arn, data.aws_secretsmanager_secret.sample_app.arn]
      Condition = { StringEquals = { "aws:RequestedRegion" = "ap-northeast-2" } }
    }]
  })
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = "oneaction"
  namespace       = "external-secrets"
  service_account = "external-secrets-service-migration"
  role_arn        = aws_iam_role.eso.arn
  depends_on      = [aws_iam_role_policy.read_secrets]
}

output "secret_arn" { value = aws_secretsmanager_secret.receipt.arn }
output "role_arn" { value = aws_iam_role.eso.arn }
output "association_id" { value = aws_eks_pod_identity_association.eso.association_id }
