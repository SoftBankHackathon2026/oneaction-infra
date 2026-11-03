# EBS CSI 드라이버. gitops 의 kube-prometheus-stack(Prometheus·Grafana)이 oneaction-monitoring-gp3
# StorageClass 로 EBS 볼륨을 요구하는데, 기존 계정에서는 드라이버와 StorageClass 를 손으로 설치했다.
# 클러스터 스택과 수명 주기를 분리하려고 LBC·ESO 처럼 별도 스택으로 둔다.

variable "aws_profile" {
  type    = string
  default = ""
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
  validation {
    condition     = var.aws_region == "ap-northeast-2"
    error_message = "Use the Seoul workload region ap-northeast-2."
  }
}

variable "owner" {
  type    = string
  default = "hyeyeon.kim"
}

variable "addon_version" {
  description = "aws-ebs-csi-driver EKS add-on build for Kubernetes 1.36. Check `aws eks describe-addon-versions` before changing."
  type        = string
  default     = "v1.67.2-eksbuild.1"
  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+-eksbuild\\.[0-9]+$", var.addon_version))
    error_message = "Pin an explicit EKS build version."
  }
}

provider "aws" {
  profile             = var.aws_profile == "" ? null : var.aws_profile
  region              = var.aws_region
  allowed_account_ids = ["974402993422"]
  default_tags {
    tags = { Project = "oneaction", Owner = var.owner, Env = "dev" }
  }
}

data "aws_partition" "current" {}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket         = "oneaction-tfstate-974402993422"
    key            = "dev/eks/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = "oneaction-terraform-locks"
    encrypt        = true
  }
}

locals {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_arn     = data.terraform_remote_state.eks.outputs.cluster_arn
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks-cluster-arn"
      values   = [local.cluster_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-namespace"
      values   = [local.namespace]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-service-account"
      values   = [local.service_account]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${local.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  lifecycle {
    precondition {
      condition     = local.cluster_name == "oneaction" && local.cluster_arn == "arn:aws:eks:ap-northeast-2:974402993422:cluster/oneaction"
      error_message = "The EKS state must reference the team oneaction cluster."
    }
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# 연결을 애드온보다 먼저 만들어 컨트롤러 Pod 가 처음부터 자격증명을 받게 한다.
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = local.cluster_name
  namespace       = local.namespace
  service_account = local.service_account
  role_arn        = aws_iam_role.ebs_csi.arn
  depends_on      = [aws_iam_role_policy_attachment.ebs_csi]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = local.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.addon_version
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_pod_identity_association.ebs_csi]
}

output "role_arn" { value = aws_iam_role.ebs_csi.arn }
output "addon_version" { value = aws_eks_addon.ebs_csi.addon_version }
output "storage_class_manifest" { value = "infra/eks-ebs-csi/manifests/storageclass-monitoring-gp3.yaml" }
