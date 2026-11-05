# Tailscale subnet router (홈랩 k3s → RDS/MSK)

온프렘 k3s 파드가 VPC 안의 RDS(5432)·MSK(9092)에 닿게 하는 경로입니다. 퍼블릭 엔드포인트를 열지 않고,
VPC 안의 작은 EC2(`t4g.nano`, private 서브넷)가 tailnet에 `10.0.0.0/16`을 advertise 합니다.

```
k3s 노드 (tailscale --accept-routes)  ──tailnet──>  oneaction-aws-router (EC2, source/dest check off, SNAT)
                                                      └─> RDS 5432 · MSK 9092  (출발지는 라우터 IP, EKS 서브넷)
```

## 적용 전 준비
1. Tailscale 관리 콘솔: ACL에 `tag:aws-subnet-router`를 만들고, **reusable·pre-authorized·tagged** auth key 발급.
2. Secrets Manager에 `oneaction/tailscale-auth-key`(평문)로 저장. Terraform 상태에는 값이 들어가지 않습니다.
3. ACL `autoApprovers.routes`에 `"10.0.0.0/16": ["tag:aws-subnet-router"]`를 넣으면 라우트 승인이 자동입니다.

```bash
cd infra/tailscale
terraform init -backend-config=../backend.hcl
terraform plan -var tailscale_auth_key_secret_arn=arn:aws:secretsmanager:ap-northeast-2:974402993422:secret:oneaction/tailscale-auth-key-XXXXXX -out=tfplan
terraform apply tfplan
```

## 홈랩 쪽
각 k3s 노드에서 `tailscale up --accept-routes`. 파드 트래픽은 노드의 라우팅 테이블을 타므로 노드에 Tailscale이
있어야 합니다(파드 안 Tailscale로는 다른 파드 경로가 안 잡힘). 홈랩 LAN이 `172.30.1.x`라 다른 멤버의 LAN과
겹치는 문제는 이 스택과 무관하며, 겹치는 쪽에서 호스트 라우트로 우회하는 현재 방식이 맞습니다.

## 보안 경계
- 라우터 SG는 inbound 없음. RDS·MSK SG는 고치지 않습니다. 라우터가 EKS private 서브넷에 있고 tailnet 트래픽을
  자기 IP로 SNAT 하므로 기존 "EKS 서브넷 CIDR → 5432/9092" 규칙으로 통과합니다. 두 SG는 규칙을 인라인으로
  정의해서, 다른 스택이 규칙을 덧붙이면 network·msk 재적용 때 지워집니다.
- 그래서 tailnet 에 이 경로를 쓸 수 있는 장치는 RDS·MSK에 EKS 노드와 같은 네트워크 권한을 갖습니다.
  Tailscale ACL에서 `10.0.0.0/16` 접근을 홈랩 k3s 노드 태그로만 제한하세요.
- IAM은 auth key Secret 하나의 `GetSecretValue`만. IMDSv2 필수, 루트 볼륨 암호화.
- `--ssh=false`, `--accept-dns=false`. 라우터는 포워딩만 합니다.

## 비용
t4g.nano 온디맨드 약 $3/월 + EBS 8GiB. NAT 통과 트래픽은 기존 NAT 요금.
