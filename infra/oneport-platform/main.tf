# Oneport 플랫폼 서버 (EC2 한 대, docker compose). 서버 안의 구성과 CD 는 Hackathon 저장소 platform/deploy/ec2 에 있다.
# 처음에는 콘솔·CLI 로 만들었고, 이 스택으로 import 해서 관리한다 (README).
provider "aws" {
  profile = var.aws_profile == "" ? null : var.aws_profile
  region  = var.aws_region
  default_tags {
    tags = {
      Project = "oneaction"
      Owner   = var.owner
      Env     = "dev"
    }
  }
}

data "aws_caller_identity" "current" {}

# 팀 계정의 SSO 역할은 이름이 ghost- 로 시작하고 권한 경계 GhostWorkloadBoundary 가 붙은 IAM 역할만 만들 수 있다.
# IAM 태그 키는 대소문자를 구분하지 않아 기본 태그 Project 와 project 가 부딪힌다. project=oneport 는 EC2 자원에만 붙인다
# (CD 의 SSM 권한이 인스턴스의 project 태그로 대상을 좁힌다).
locals {
  account_id               = data.aws_caller_identity.current.account_id
  iam_permissions_boundary = "arn:aws:iam::${local.account_id}:policy/GhostWorkloadBoundary"
  ecr_repositories         = "arn:aws:ecr:${var.ecr_region}:${local.account_id}:repository/ghost/oneport-platform-*"
  tags                     = { project = "oneport" }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default_a" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "${var.aws_region}a"
  default_for_az    = true
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---- 서버 역할: ECR 읽기, SSM(배포·관리), 비용 화면용 읽기
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "server" {
  name                 = "ghost-oneport-platform-ec2"
  description          = "Oneport platform EC2: ECR pull, SSM"
  permissions_boundary = local.iam_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "server_ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "server_ecr" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    resources = [local.ecr_repositories]
  }
}

resource "aws_iam_role_policy" "server_ecr" {
  name   = "ecr-pull-oneport"
  role   = aws_iam_role.server.id
  policy = data.aws_iam_policy_document.server_ecr.json
}

# 비용 화면이 AWS 자원 목록과 사용량을 읽는다. 쓰기 권한은 없다.
data "aws_iam_policy_document" "server_cost" {
  statement {
    sid = "OneportCostRead"
    actions = [
      "tag:GetResources",
      "rds:DescribeDBInstances",
      "kafka:ListClustersV2",
      "elasticloadbalancing:DescribeLoadBalancers",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeNatGateways",
      "ec2:DescribeAddresses",
      "ec2:DescribeNetworkInterfaces",
      "cloudwatch:GetMetricStatistics",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "server_cost" {
  name   = "oneport-cost-read"
  role   = aws_iam_role.server.id
  policy = data.aws_iam_policy_document.server_cost.json
}

resource "aws_iam_instance_profile" "server" {
  name = "ghost-oneport-platform-ec2"
  role = aws_iam_role.server.name
}

# ---- 배포 역할: GitHub Actions(Hackathon main)가 OIDC 로 맡아 ECR 에 올리고 이 서버에만 SSM 명령을 보낸다
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "deploy_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_oidc_subjects
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "ghost-oneport-platform-deploy"
  description          = "GitHub Actions (Hackathon main) deploys Oneport platform to EC2"
  permissions_boundary = local.iam_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.deploy_assume.json
}

data "aws_iam_policy_document" "deploy" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [local.ecr_repositories]
  }
  statement {
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"]
  }
  statement {
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:${var.aws_region}:${local.account_id}:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/project"
      values   = ["oneport"]
    }
  }
  statement {
    actions   = ["ssm:ListCommands", "ssm:ListCommandInvocations", "ssm:GetCommandInvocation"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy-oneport-ec2"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

# ---- 네트워크: 기본 VPC public 서브넷. 들어오는 것은 80·443 뿐이고 SSH 는 열지 않는다(SSM 으로 관리)
resource "aws_security_group" "server" {
  name        = "oneport-platform-sg"
  description = "Oneport platform web"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "ACME HTTP-01 and HTTPS redirect only"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.acme_cidrs
  }

  ingress {
    description = "SSH with key only (ec2-user)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidrs
  }

  ingress {
    description = "HTTPS behind access PIN"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.https_cidrs
  }

  # 온프렘 환경 연결(#48)의 중계 서비스. 단말이 어디서 붙을지 몰라 전체에 연다. 인증은 상호 TLS·서명으로 한다.
  ingress {
    description = "oneport connection broker TLS"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.connection_cidrs
  }

  ingress {
    description = "oneport connection WireGuard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = var.connection_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "oneport-platform-sg" })
}

resource "aws_instance" "server" {
  ami                         = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.default_a.id
  vpc_security_group_ids      = [aws_security_group.server.id]
  iam_instance_profile        = aws_iam_instance_profile.server.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gib
    encrypted   = true
    tags        = local.tags
  }

  # 부팅 스크립트는 Hackathon 저장소 platform/deploy/ec2/user-data.sh 다. 처음 만들 때만 쓰이므로 이후 변경은 무시한다.
  # AMI 도 최신 값을 따라가며 서버를 다시 만들지 않는다.
  lifecycle {
    ignore_changes = [ami, user_data, user_data_base64]
  }

  tags = merge(local.tags, { Name = "oneport-platform" })
}

# 도메인 A 레코드(플랫폼·홈랩 앱)가 가리키는 주소. EKS 공개 엔드포인트 허용 목록에도 들어간다(eks 스택이 읽는다).
resource "aws_eip" "server" {
  domain   = "vpc"
  instance = aws_instance.server.id
  tags     = merge(local.tags, { Name = "oneport-platform" })
}
