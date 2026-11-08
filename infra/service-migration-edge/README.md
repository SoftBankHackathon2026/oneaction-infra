# 온프렘 전체 서비스 이전의 AWS 접수 주소

`service-migration.hackerthon.yubin.dev`를 gitops의
`apps/service-migration-aws-active`가 소유하는 ALB에 연결한다.
기존 AWS↔GCP `cloud-migration` 접수 서비스와 별도 DNS/state를 사용한다.
ALB·Redis·앱·Secret은 이 Terraform root에서 중복 관리하지 않는다.

`aws_alb_dns_name=null`이면 레코드를 만들지 않는다. ALB 기동 뒤 실제 hostname을
전달하면 CNAME 하나를 만든다. 가중치·failover·온프렘 원본 레코드는 만들지 않는다.
기존 공개 서비스 주소 `sample-app.onprem.yubin.dev`의 DNS는 바꾸지 않는다.
기존 사용자 DNS/프록시 전환은 후속 단계다. 이 새 주소는 러너의 목적지 제어·검증과
source forwarding에만 사용한다. source seal/forward가 로컬 수락을 차단하지만,
기존 공개 주소의 앱 트래픽은 아직 온프렘에 남을 수 있다. 전체 온프렘 종료를 의미하지 않는다.

## 적용

승인된 AWS SSO 프로필과 기존 `infra/backend.hcl` S3 설정을 쓴다.

```sh
terraform init -backend-config=../backend.hcl
terraform plan -var='aws_alb_dns_name=<GitOps ALB hostname>'
```

plan 검토 후 승인된 경로로 apply한다. GitOps ALB의 ACM 인증서가
`service-migration.hackerthon.yubin.dev`를 포함하고 `ISSUED`인지 확인한다.
인증서 SAN이 맞지 않으면 기존 인증서를 추정해서 쓰지 말고 인증서 구성부터 갱신한다.
DNS·TLS 준비 후 `/api/receipt`의 목적지 ledger identity와 `/control/handoff/status`
인증을 확인해야 러너를 실행할 수 있다. 토큰을 tfvars/state/명령 기록에 넣지 않는다.

## 검증과 롤백

`terraform init -backend=false`, `terraform validate`, `terraform test`는 로컬
구문·mock plan 검증이다. 실제 AWS plan/apply·DNS/TLS 검증과 구분한다.
운영 트래픽 인계 후 DNS 삭제나 온프렘 DNS 복귀만으로 롤백하지 않는다.
새 요청을 받은 AWS ledger/DB가 유일 writer이므로 복구 절차를 먼저 따른다.
