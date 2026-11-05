# Tailscale subnet router: lets the on-prem k3s nodes (tailnet, --accept-routes) reach RDS and MSK
# inside the VPC without a public endpoint. The instance only forwards; no inbound ports are open.
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

locals {
  remote_state_config = {
    bucket         = "oneaction-tfstate-974402993422"
    region         = var.aws_region
    dynamodb_table = "oneaction-terraform-locks"
    encrypt        = true
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config  = merge(local.remote_state_config, { key = "dev/network/terraform.tfstate" })
}

data "aws_vpc" "this" {
  id = data.terraform_remote_state.network.outputs.vpc_id
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_secretsmanager_secret" "tailscale_auth_key" {
  arn = var.tailscale_auth_key_secret_arn
}

# ---- IAM: read the auth key once at boot, nothing else
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# 팀 계정(974402993422)의 SSO 역할은 이름이 ghost- 로 시작하고 권한 경계 GhostWorkloadBoundary 가 붙은
# IAM 역할만 만들 수 있다. 경계는 IAM 을 뺀 AWS 작업을 허용한다.
locals {
  iam_permissions_boundary = "arn:aws:iam::974402993422:policy/GhostWorkloadBoundary"
}

resource "aws_iam_role" "router" {
  name                 = "ghost-oneaction-tailscale-router"
  permissions_boundary = local.iam_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "read_auth_key" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [data.aws_secretsmanager_secret.tailscale_auth_key.arn]
  }
}

resource "aws_iam_role_policy" "read_auth_key" {
  name   = "read-tailscale-auth-key"
  role   = aws_iam_role.router.id
  policy = data.aws_iam_policy_document.read_auth_key.json
}

resource "aws_iam_instance_profile" "router" {
  name = "ghost-oneaction-tailscale-router"
  role = aws_iam_role.router.name
}

# ---- Network: private subnet, egress through NAT (Tailscale uses outbound UDP/HTTPS only)
resource "aws_security_group" "router" {
  name        = "tailscale-router-sg"
  description = "Tailscale subnet router: forwards tailnet traffic into the VPC and VPC traffic to tailnet routes"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # VPC 안(EKS 플랫폼 수집기 등)에서 온프렘·GCP 로 가는 트래픽이 라우터 ENI 로 들어온다.
  # 라우터 자신은 수신 포트를 열지 않는다 (tailscaled 는 바깥으로만 연결한다).
  dynamic "ingress" {
    for_each = length(var.tailnet_routes) > 0 ? [1] : []
    content {
      description = "Forward VPC traffic to tailnet routes"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [data.aws_vpc.this.cidr_block]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "tailscale-router-sg" }
}

# RDS·MSK 보안그룹은 따로 건드리지 않는다. 라우터는 EKS private 서브넷에 있고 tailnet 에서 들어온 트래픽을 자기
# 주소로 SNAT 해서 내보내므로(--snat-subnet-routes, Tailscale 기본값), 기존의 "EKS 서브넷 CIDR 허용" 규칙으로 닿는다.
# 두 SG 는 network·msk 스택에서 규칙을 인라인으로 정의하므로, 여기서 aws_security_group_rule 을 더하면
# 그 스택을 다시 apply 할 때 지워진다.

resource "aws_instance" "router" {
  ami                         = nonsensitive(data.aws_ssm_parameter.al2023_arm64.value)
  instance_type               = var.instance_type
  subnet_id                   = data.terraform_remote_state.network.outputs.private_eks_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.router.id]
  iam_instance_profile        = aws_iam_instance_profile.router.name
  associate_public_ip_address = false
  source_dest_check           = false # required to forward tailnet traffic into the VPC

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://pkgs.tailscale.com/stable/amazon-linux/2023/tailscale.repo
    dnf install -y tailscale
    cat >/etc/sysctl.d/99-tailscale.conf <<'SYSCTL'
    net.ipv4.ip_forward = 1
    net.ipv6.conf.all.forwarding = 1
    SYSCTL
    sysctl -p /etc/sysctl.d/99-tailscale.conf
    systemctl enable --now tailscaled
    # The auth key is read into the process only; it is never written to disk.
    AUTH_KEY="$(aws secretsmanager get-secret-value --region ${var.aws_region} \
      --secret-id '${data.aws_secretsmanager_secret.tailscale_auth_key.arn}' --query SecretString --output text)"
    tailscale up --auth-key="$AUTH_KEY" --hostname=oneaction-aws-router \
      --advertise-routes=${join(",", var.advertise_routes)} --snat-subnet-routes=true \
      --accept-routes=${length(var.tailnet_routes) > 0} --accept-dns=false --ssh=false
    unset AUTH_KEY
  EOT

  tags = { Name = "oneaction-tailscale-router" }

  lifecycle {
    ignore_changes = [ami] # pinned at first apply; replace deliberately
  }
}

# ---- VPC → tailnet: 온프렘 LAN(172.30.1.0/24, proxmox-exit 가 광고)과 GCP 대역을 라우터로 보낸다.
# 라우터가 --accept-routes 로 받은 경로로 넘기고, 온프렘 쪽은 proxmox-exit 가 SNAT 하므로 LAN 에는 경로를 더하지 않는다.
# private 라우팅 테이블은 network 스택이 별도 aws_route 로 관리하므로 여기서 aws_route 를 더해도 덮어쓰이지 않는다.
resource "aws_route" "tailnet" {
  for_each               = toset(var.tailnet_routes)
  route_table_id         = data.terraform_remote_state.network.outputs.private_route_table_id
  destination_cidr_block = each.value
  network_interface_id   = aws_instance.router.primary_network_interface_id
}
