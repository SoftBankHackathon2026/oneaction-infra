terraform {
  required_version = ">= 1.5.7, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 5.100.0" }
  }
  backend "s3" { key = "dev/eks-sample-app/terraform.tfstate" }
}

provider "aws" {
  region              = "ap-northeast-2"
  allowed_account_ids = ["974402993422"]
  default_tags { tags = { Project = "oneaction", Owner = "gayeon.won", Env = "dev" } }
}

# Only metadata enters state. Values are provisioned in memory, outside Terraform.
resource "aws_secretsmanager_secret" "app" {
  name                    = "oneaction/sample-app"
  description             = "Migration application DB URL and request API token"
  recovery_window_in_days = 30
  lifecycle { prevent_destroy = true }
}

resource "aws_iam_role" "eso" {
  name                 = "ghost-oneaction-external-secrets-sample-app"
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
        "aws:RequestTag/kubernetes-service-account" = "external-secrets-sample-app"
      } }
    }]
  })
}

resource "aws_iam_role_policy" "read_app" {
  name = "read-sample-app-secret"
  role = aws_iam_role.eso.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource  = aws_secretsmanager_secret.app.arn
      Condition = { StringEquals = { "aws:RequestedRegion" = "ap-northeast-2" } }
    }]
  })
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = "oneaction"
  namespace       = "external-secrets"
  service_account = "external-secrets-sample-app"
  role_arn        = aws_iam_role.eso.arn
  depends_on      = [aws_iam_role_policy.read_app]
}

output "secret_arn" { value = aws_secretsmanager_secret.app.arn }
output "role_arn" { value = aws_iam_role.eso.arn }

# The existing LBC-owned ALB stays under Kubernetes/GitOps ownership.
data "aws_lb" "sample_app" { name = "k8s-sampleap-sampleap-88af4f1f82" }
resource "aws_route53_record" "sample_app" {
  zone_id = "Z02519793E7CZENYZOJQN"
  name    = "sample-app.hackerthon.yubin.dev"
  type    = "A"
  alias {
    name                   = data.aws_lb.sample_app.dns_name
    zone_id                = data.aws_lb.sample_app.zone_id
    evaluate_target_health = true
  }
}
