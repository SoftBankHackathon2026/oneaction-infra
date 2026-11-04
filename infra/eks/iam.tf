data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# 팀 계정(974402993422)의 SSO 역할은 이름이 ghost- 로 시작하고 권한 경계 GhostWorkloadBoundary 가 붙은
# IAM 역할만 만들 수 있고, OIDC 공급자는 만들 수 없다(IRSA 불가). 경계는 IAM 을 뺀 AWS 작업을 허용한다.
locals {
  iam_permissions_boundary = "arn:aws:iam::974402993422:policy/GhostWorkloadBoundary"
}

resource "aws_iam_role" "cluster" {
  name                 = "ghost-${local.cluster_name}-eks-cluster"
  permissions_boundary = local.iam_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name                 = "ghost-${local.cluster_name}-eks-node"
  permissions_boundary = local.iam_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEC2ContainerRegistryPullOnly",
    # vpc-cni(aws-node) 는 노드 역할로 동작한다. IRSA 용 OIDC 공급자를 이 계정에서 만들 수 없고,
    # Pod Identity 에이전트는 노드가 Ready 된 뒤에 뜨므로 CNI 부팅에 쓸 수 없다. (AWS 기본 구성)
    "AmazonEKS_CNI_Policy",
  ])
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}
