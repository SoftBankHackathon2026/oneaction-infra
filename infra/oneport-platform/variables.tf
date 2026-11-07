variable "aws_profile" {
  description = "AWS CLI profile, or empty when using exported temporary credentials."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "플랫폼 서버 리전. 서울 온디맨드 vCPU 한도(8)를 EKS 노드와 Tailscale 라우터가 다 써서 도쿄에 둔다."
  type        = string
  default     = "ap-northeast-1"
}

variable "ecr_region" {
  description = "플랫폼 이미지가 있는 ECR 리전 (ghost/oneport-platform-*)."
  type        = string
  default     = "ap-northeast-2"
}

variable "owner" {
  type    = string
  default = "yubin.kim"
}

variable "instance_type" {
  description = "docker compose 로 DB·API·수집기·화면·Caddy 를 올린다. t3.small(2GiB) + 스왑 2GiB."
  type        = string
  default     = "t3.small"
}

variable "root_volume_gib" {
  type    = number
  default = 20
}

variable "https_cidrs" {
  description = "443 허용 대역. 화면 앞에 접속 PIN 이 있어서 전체에 연다."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "acme_cidrs" {
  description = "80 허용 대역. Let's Encrypt HTTP-01 이 어디서 올지 몰라 전체에 연다. Caddy 는 인증 응답과 HTTPS 리다이렉트만 한다."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "connection_cidrs" {
  description = "온프렘 환경 연결 중계(브로커 TLS 8443/tcp, WireGuard 51820/udp) 허용 대역."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "github_oidc_subjects" {
  description = "배포 역할을 맡을 수 있는 GitHub OIDC sub. 저장소의 바뀌지 않는 ID 형식과 이름 형식을 둘 다 둔다(Hackathon main 만)."
  type        = list(string)
  default = [
    "repo:SoftBankHackathon2026@350755067/Hackathon@1440930975:ref:refs/heads/main",
    "repo:SoftBankHackathon2026/Hackathon:ref:refs/heads/main",
  ]
}
