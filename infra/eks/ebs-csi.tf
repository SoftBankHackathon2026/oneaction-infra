# EBS CSI 드라이버: gitops 의 monitoring-aws(Prometheus·Grafana) 가 gp3 PVC 를 쓴다.
# 예전 계정에서는 손으로 설치했던 것을 IaC 로 옮겼다 (StorageClass 는 manifests/storageclass-monitoring-gp3.yaml).
# 팀 계정은 OIDC 공급자를 만들 수 없어 IRSA 대신 Pod Identity 를 쓴다. 애드온이 association 을 직접 만든다.
variable "ebs_csi_addon_version" {
  description = "Reviewed aws-ebs-csi-driver build for Kubernetes 1.36."
  type        = string
  default     = "v1.67.2-eksbuild.1"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+-eksbuild\\.[0-9]+$", var.ebs_csi_addon_version))
    error_message = "Pin aws-ebs-csi-driver to an explicit EKS build version."
  }
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name                 = "ghost-${local.cluster_name}-ebs-csi"
  permissions_boundary = local.iam_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_addon_version
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "PRESERVE"

  pod_identity_association {
    role_arn        = aws_iam_role.ebs_csi.arn
    service_account = "ebs-csi-controller-sa"
  }

  depends_on = [aws_eks_addon.runtime, aws_iam_role_policy_attachment.ebs_csi]
}
