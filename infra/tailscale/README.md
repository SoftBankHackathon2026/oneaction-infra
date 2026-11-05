# Tailscale subnet router (홈랩 k3s ⇄ AWS VPC)

온프렘 k3s 파드가 VPC 안의 RDS(5432)·MSK(9092)에 닿게 하는 경로입니다. 퍼블릭 엔드포인트를 열지 않고,
VPC 안의 작은 EC2(`t4g.micro`, private 서브넷)가 tailnet에 `10.0.0.0/16`을 advertise 합니다.

```
k3s 노드 (tailscale --accept-routes)  ──tailnet──>  oneaction-aws-router (EC2, source/dest check off, SNAT)
                                                      └─> RDS 5432 · MSK 9092  (출발지는 라우터 IP, EKS 서브넷)

EKS Pod (플랫폼 수집기 등) ─ VPC 라우팅 172.30.1.10/32·.7/32 → 라우터 ENI ─ tailnet ─> proxmox-exit (SNAT) ─> k3s 노드
                                                      └─> k3s API 6443 · 상태 프록시 NodePort 30880 (읽기 전용)
```

반대 방향(AWS → 홈랩)은 `tailnet_routes`(기본 k3s 노드 두 대 `["172.30.1.10/32", "172.30.1.7/32"]`)로 엽니다.
라우터가 `--accept-routes`로 proxmox-exit 의 `172.30.1.0/24` 광고를 받고, VPC private 라우팅 테이블에는 노드 주소만
라우터 ENI 로 보냅니다. 공유기·Proxmox 관리 화면 같은 홈랩 LAN 의 다른 장비로 가는 VPC 경로는 만들지 않습니다.
홈랩 쪽은 proxmox-exit 가 SNAT 하므로 LAN 장비에 경로를 추가하지 않습니다. 한 방향만 쓰려면 `tailnet_routes = []`.

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
- 라우터 SG의 inbound 는 VPC CIDR 에서 오는 포워딩 트래픽뿐입니다(`tailnet_routes`가 비면 없음). 라우터 자신은 수신 포트를 열지 않습니다.
- 라우터 SG는 그 밖의 inbound 없음. RDS·MSK SG는 고치지 않습니다. 라우터가 EKS private 서브넷에 있고 tailnet 트래픽을
  자기 IP로 SNAT 하므로 기존 "EKS 서브넷 CIDR → 5432/9092" 규칙으로 통과합니다. 두 SG는 규칙을 인라인으로
  정의해서, 다른 스택이 규칙을 덧붙이면 network·msk 재적용 때 지워집니다.
- 그래서 tailnet 에 이 경로를 쓸 수 있는 장치는 RDS·MSK에 EKS 노드와 같은 네트워크 권한을 갖습니다.
  Tailscale ACL에서 `10.0.0.0/16` 접근을 홈랩 k3s 노드 태그로만 제한하세요.
- IAM은 auth key Secret 하나의 `GetSecretValue`만. IMDSv2 필수, 루트 볼륨 암호화.
- `--ssh=false`, `--accept-dns=false`. 라우터는 포워딩만 합니다.
- AWS → 홈랩 경로는 k3s 노드 두 대(`/32`)만 VPC 라우팅에 올립니다. 노드에서 VPC 로 열리는 포트는 k3s API(인증 필요)와
  읽기 전용 상태 프록시(gitops `apps/platform-status-proxy`, GET 두 경로만)입니다. 워커 제어 API·Kafka Connect REST 는 열지 않습니다.
- 라우터 자체는 `172.30.1.0/24` 전체를 받으므로, 라우터 인스턴스가 탈취되면 홈랩 LAN 전체에 닿을 수 있습니다. 더 줄이려면
  Tailscale 접근 정책 grant 로 `tag:aws-subnet-router` → `172.30.1.10,172.30.1.7` 포트 6443·30880만 허용합니다.

## 비용
t4g.micro 온디맨드 약 $6/월 + EBS 8GiB (t4g.nano 는 user_data 의 dnf 가 OOM 으로 죽어 tailscale 이 설치되지 않음, 2026-11-05 확인). NAT 통과 트래픽은 기존 NAT 요금.

## 설정 바꾸기 (실행 중인 라우터)

`user_data` 는 첫 부팅에만 실행되고, Terraform 은 `user_data` 변경으로 라우터를 다시 만들지 않습니다(`ignore_changes`).
실행 중인 라우터의 tailscale 설정은 SSM Run Command 로 맞춥니다. SSH 나 수신 포트는 열지 않습니다.

```bash
ID=$(terraform -chdir=infra/tailscale output -raw instance_id)
aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --parameters 'commands=["tailscale set --accept-routes=true","tailscale status --peers=false"]'
```

2026-11-06 에 실행 중인 라우터에 이 방법으로 두 가지를 넣었습니다(`tailnet_routes` 의 VPC → 홈랩 경로용).

- `tailscale set --accept-routes=true`: proxmox-exit 의 `172.30.1.0/24` 광고를 받는다
- `oneport-tailnet-snat.service`: VPC → tailnet 트래픽을 라우터의 tailnet 주소로 SNAT 한다. proxmox-exit 는
  `10.0.0.0/16` 경로를 받지 않아서, 출발지가 VPC 주소면 홈랩의 응답이 돌아오지 못한다. 라우터를 새로 만들 때는
  `user_data` 가 같은 서비스를 만든다

확인: EKS 의 Pod 에서 `curl http://172.30.1.10:30880/worker/status` 가 200, 홈랩 k3s 노드에서 RDS 5432 가 열려 있다.
