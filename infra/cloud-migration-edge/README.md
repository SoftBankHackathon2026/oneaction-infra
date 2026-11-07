# 클라우드 간 전환의 고정 주소

새 GCP global static IP와 두 DNS 레코드만 관리한다. 앱·DB·Secret은 만들지 않는다.
AWS 발신 주소는 기존 EKS private subnet의 NAT Gateway EIP를 사용한다.
2026-11-07 조회에서 실행 중인 EKS 노드 3개는 모두 해당 NAT를 사용하는 private subnet에 있었고 public IP가 없었다.
새 NAT/EIP를 중복 생성하지 않는다. 노드 subnet/라우팅이 바뀌면 발신 주소도 다시 검증한다.

- AWS 접수: cloud-migration.hackerthon.yubin.dev → GitOps가 만드는 ALB (고정 DNS, IP 고정 아님).
- GCP 앱: gcp-migration.hackerthon.yubin.dev → 여기서 예약한 고정 IP.
- GKE ManagedCertificate/Ingress는 gitops apps/cloud-migration-gcp-edge가 관리한다.
- AWS ALB는 gitops apps/cloud-migration-aws-active가 관리한다.

적용 순서: 승인된 원격 backend로 init → plan 검토 → GCP IP/DNS apply → GKE edge GitOps 배포 →
인증서 ACTIVE 및 요청 API 인증 확인 → AWS active GitOps 배포 → ALB DNS를 aws_alb_dns_name으로 전달해 plan/apply.
GCP endpoint가 현재 앱 DB와 기대 DB를 가리키는지 확인하기 전 전환 Job을 시작하지 않는다.
새 대상 DB/복제 job은 혜연 진행 작업과 별도로 소유권을 확정한다.

AWS_PROFILE=t3underline 및 승인된 GCP ADC를 사용한다. 인증값을 tfvars/state 산출물/로그에 넣지 않는다.
이 디렉터리는 기존 infra/backend.hcl의 S3 설정을 재사용하되 state key는 독립적이다.
aws_alb_dns_name=null 상태에서는 GCP IP/DNS만 계획한다. ALB를 Terraform으로 중복 소유하지 않는다.
DNS/IP 생성은 구현 검증과 다르다. 현재 apply하지 않았다.

되돌릴 때 먼저 사용자 요청 경로와 단일 writer를 확정하고 GitOps workload를 정상 중단한다.
운영 트래픽이 사용 중인 IP/DNS를 먼저 destroy하지 않는다. Terraform이 원본 DB/복제 상태를 복구하지 않는다.

Cloud SQL 원본 모듈에 `db_enable_proxy_public_ip` opt-in도 추가했다. 실제 GCP tfvars에서 true로
설정해야 수동으로 켜 둔 public IP가 다음 apply 때 꺼지지 않는다. 기본값은 false이고,
공개주소를 켜도 authorized_networks는 생성하지 않으며 ENCRYPTED_ONLY는 유지한다.
정책 변경은 기존 GCP state의 plan을 따로 검토한다. 이 edge root가 Cloud SQL을 중복 관리하지 않는다.

검증: edge init(-backend=false), validate, fmt 통과. database 모듈 google7.29 mock-provider
plan tests2 통과(기본 비공개, opt-in/TLS/직접접속 허용목록 없음). 실제 plan/apply 미실행.
