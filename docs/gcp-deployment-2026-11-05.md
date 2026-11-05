# softbank ghost GCP 배포 준비 기록

2026-11-05 한국시간 기준입니다. 대상은 `softbank-ghost`(프로젝트 번호 `499945065361`)이며, AWS Terraform 11개 구성 전체에 대응하는 배포를 준비합니다.

## 현재 결과

- ✅ 브라우저에서 대상 프로젝트·프로젝트 번호·로그인 계정을 확인했습니다.
- ❌ 결제 연결: 콘솔에 “이 프로젝트에 결제 계정이 연결되어 있지 않습니다”로 표시됩니다. 사용자가 연결 후 알려주시기로 했습니다.
- ❌ Kubernetes Engine API: 콘솔에서 “API 사용 설정” 단계입니다. 이번 작업에서 API를 활성화하지 않았습니다.
- ❌ 실제 자원·권한·할당량 전체 조회: 미완료입니다. Cloud Shell은 초기 인증 계정이 없고 연결이 끊기는 문제가 있었으며, 인증을 확인 중입니다.
- ❌ AWS 실제 자원 조회: 포털의 계정 `974402993422`·역할 `GhostInfraEngineer`는 확인했으나 자원 화면 진입 시 로그인을 다시 요구했습니다. 자원의 배포 여부로 해석하지 않습니다.
- ❌ 실제 Terraform 생성 계획·적용·클라우드 동작 검증: 수행하지 않았습니다. 모의 시험 결과와 구분합니다.

## 코드 보완

별도 로컬 브랜치 `infra/gcp-full-deployment`에서 작업했습니다. 기존 AWS 파일은 변경하지 않았습니다.

1. Cloud SQL의 `cloudsql.logical_decoding=on`을 설정해 AWS의 논리 복제 준비에 대응합니다.
2. GKE의 Persistent Disk CSI(영구 디스크 연결 드라이버)를 명시적으로 활성화합니다.
3. 전용 네트워크의 최종 ingress(수신) 차단 규칙에 로깅을 추가합니다. GKE가 관리하는 더 높은 우선순위 허용 규칙은 유지합니다.
4. NAT 경보를 `OUT_OF_RESOURCES` 원인의 송신 드롭으로 좁히고, 부하분산 자체 5xx 경보에서는 `response_sent_by_backend`를 제외합니다. SQL은 사용률 80% 대신 실제 할당량에서 사용량을 뺀 여유 공간 4GiB 미만을 검사합니다. AWS의 3회 중 2회 판정과 GCP의 지속 시간 판정은 아직 다르며, 실제 발생·수신 검증이 남습니다.
5. Tailscale 사설 라우터 모듈을 추가합니다. 공인 주소·수신 포트 없이 별도 서비스 계정으로 지정 Secret Manager 비밀만 읽습니다. 키 값은 Terraform·메타데이터에 넣지 않고, 메모리 기반 임시 파일을 통해 사용한 뒤 삭제합니다.
6. `require_full_scope=true`일 때 Kafka·Tailscale·도메인·알림 이메일이 빠지면 계획을 거절합니다. 기존 초안 호환성을 위해 일반 기본값은 유지하며, 전체 배포에는 `softbank-ghost.tfvars.example`을 사용합니다.
7. 읽기 전용 자원 조회 도구 `scripts/gcp-preflight.py`를 추가합니다. 비활성 API는 활성화하지 않고 미확인으로 기록합니다. 비밀정보의 값·버전과 계정 키는 조회하지 않습니다.

## 로컬 검증

| 검사 | 결과 | 범위 |
|---|---|---|
| Terraform 형식 검사 | ✅ 통과 | GCP 전체 파일 |
| Terraform 구성 검사 | ✅ 통과 | 공급자 7.29.0, 실제 클라우드 생성 없음 |
| Terraform 모의 공급자 시험 | ✅ 17개 통과 | 기존 14개 + 전체 범위/키 참조/사설 라우터 3개 |
| Python 단위 시험 | ✅ 16개 통과 | 기존 11개 + 읽기 전용 조회 안전성 5개 |
| 변경 공백 검사 | ✅ 통과 | `git diff --check` |

Terraform 공급자 실행에 필요한 로컬 통신이 샌드박스에서 차단되어 구성 검사·모의 시험은 허용된 별도 실행으로 확인했습니다. 실제 프로젝트 인증이나 `apply`는 사용하지 않았습니다. 기본 Python에는 PyYAML이 없어 기존 전용 가상환경 `/private/tmp/oneaction-gcp-venv/bin/python`으로 전체 시험을 실행했습니다.

```bash
terraform fmt -check -recursive infra/gcp
terraform -chdir=infra/gcp validate
terraform -chdir=infra/gcp test
python -m unittest discover -s tests -v
git diff --check
```

## 결제 연결 이후 실행할 조회

인증된 Cloud Shell 또는 명령줄 환경에서 실행합니다. 이 명령은 인프라를 생성하지 않습니다.

```bash
python3 scripts/gcp-preflight.py \
  --project softbank-ghost \
  --region asia-northeast3 \
  --output infra/gcp/preflight.local.json
```

`OBSERVED`는 조회 성공, `UNVERIFIED`는 조회 미완료입니다. 조회가 비어 있다는 사실만으로 AWS/GCP 기능 동등성 검증 완료를 표시하지 않습니다. 실패한 명령의 비밀정보가 섞일 수 있는 원문 진단은 결과 파일에 저장하지 않습니다.

## 적용 전 남은 입력과 결정

- 결제 계정 연결, 비용 상한·사용 종료일.
- 실제 AWS 자원 상태·사양과 GCP 권한·할당량·주소 대역·기존 상태 저장소 대조.
- 승인된 관리자·배포자 계정과 실제 공인 출구 주소.
- GCP용 도메인·인증서 범위·알림 이메일. 현재 초안의 단일 도메인 인증서와 AWS 와일드카드의 차이는 미해결입니다.
- Tailscale 관리자 승인·비밀 ID·실제 값 등록. 전체 배포의 라우터 사용은 `enable_tailscale=true`로 명시합니다.
- Cloud SQL 비밀번호와 앱 비밀정보의 안전한 주입. 비밀 원문은 문서·저장소에 쓰지 않습니다.
- Cloud SQL 여유 공간 경보의 실제 지표·샘플링·알람 시간, 로그 보관·Kafka 최소 용량·사설 서비스 경로의 추가 대조와 검증.
- ESO 설치 시 기존 버전/소유권 확인과 동기화·갱신 검증.

결제 연결만으로 위 항목을 완료 처리하지 않습니다. 실제 생성 계획에서 전체 자원·변경/삭제 여부·비용을 검토한 뒤 적용합니다.

## 되돌리기

이번에는 실제 자원을 생성하지 않았으므로 클라우드 삭제 대상이 없습니다. 코드 보완은 별도 브랜치에 남아 있습니다. 향후 적용 실패 시 상태·로그를 보존하고 이번 신규 자원만 식별한 뒤, 데이터/볼륨/비밀정보 보존과 삭제 보호 정책을 확인해 승인된 정리만 수행합니다.

용어: API는 서비스 호출 인터페이스, NAT는 사설망 외부 통신, CSI는 컨테이너 저장소 연결 규격, 모의 공급자는 실제 클라우드에 접속하지 않고 계획을 검사하는 시험용 구현입니다.
