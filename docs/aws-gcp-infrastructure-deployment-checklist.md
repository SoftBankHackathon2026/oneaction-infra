# AWS 기준 GCP 전체 인프라 배포 계획과 현황 체크리스트

기준일: 2026-11-06, 한국시간(코어 배포·기본 연결 시험 완료, 전체 대응 미완료). 이번 범위는 AWS Terraform으로 배포 가능한 전체 구성의 기능·접근 통제·용량·운영 검증을 GCP에 최대한 대응시키는 것입니다. Kubernetes 전용 구성으로 분리하던 앞선 계획은 이 계획으로 대체합니다.

AWS와 GCP의 코드 존재 여부, 실제 배포 여부, 동작 검증 결과를 구분합니다. 사용자 지시로 현재 대상은 `ghost-project-513812`(표시명 `ghost-project`, 번호 `251118972904`)로 전환했으며, 브라우저에서 ‘해커톤 결제’ 연결을 확인했습니다. 이전 `softbank-ghost`의 결제/API 관찰은 새 프로젝트의 증거로 사용하지 않습니다. 새 프로젝트의 16종 최종 자원 조회가 성공했습니다. 전용 상태·네트워크·저장소·GKE 3노드·사설 PostgreSQL·관리형 Kafka·경보 4개를 생성했고, 디스크/DB/저장소/Kafka/공개 HTTP 시험을 통과했습니다. 코어 재계획은 변경 0건입니다. 도메인·인증서·알림 수신·Tailscale·앱 비밀값과 복구/권한 경계 등 전체 동등성 검증은 남아 있습니다.

## 기준과 범위

- AWS 기준 저장소: [oneaction-infra](https://github.com/SoftBankHackathon2026/oneaction-infra/tree/0c94c0141588934dee0e306b3f7ebb355f2a33d8), 커밋 `0c94c0141588934dee0e306b3f7ebb355f2a33d8`.
- `infra/` 아래 Terraform 파일 58개에서 리소스 선언 94개를 확인했습니다. 11개 구성 단위 모두 목록에 포함합니다.
- 94는 선언 블록 수입니다. `count`·`for_each` 및 조건에 따라 실제 인스턴스 수가 달라집니다. 실행 계획 확인 시 모든 인스턴스를 펼친 목록을 증거로 붙입니다.
- GCP 대응 초안: [변경 요청 #3](https://github.com/SoftBankHackathon2026/oneaction-infra/pull/3), `feature/gcp-parity`, 최초 검토 커밋 `f3b518ee690fa954dcbfd197e45f15c8fd1850be`. 보완 코드와 최신 AWS main을 반영한 준비 코드 커밋은 `19a16116a4fde48bae5ced15820df67acc893d67`이며, 새 대상 설정·기록을 반영한 대상 변경 준비 커밋은 `1926fe296ef1d16e0321ab55f0275401c6497103`입니다. 실제 배포 보완은 변경 요청 #3의 후속 커밋을 따릅니다. 변경 요청은 초안·미병합 상태입니다.
- 앱/배포 연결 참고: [gitops](https://github.com/SoftBankHackathon2026/gitops/tree/fe62078cca210e1e089a3143102d1beab94dbe5b), 커밋 `fe62078cca210e1e089a3143102d1beab94dbe5b`.
- GCP는 기존 전 구성 실행점을 재사용합니다. Cloud SQL·Kafka·문서/로그 저장소·DNS·인증서·알람을 제외하지 않습니다. Tailscale 대응은 추가합니다.
- AWS 원본이나 운영 자원을 임의로 변경하지 않습니다. 비교와 상태 조회는 읽기 전용으로 진행하고, 범위를 넘는 수정은 명시적 승인을 받습니다.
- GitOps 문서의 `tokyo-gke`·기존 프로젝트·도쿄 주소는 과거 환경 참조입니다. 실제 생존 여부를 확인하기 전 새 서울 환경의 대상으로 재사용하지 않습니다.
- WAF·Shield 등 Terraform에 생성 선언이 없는 제품을 AWS 배포 범위에 추가하지 않습니다. IAM 정책에서 언급되는 것만으로 제품 생성으로 세지 않습니다.

## 배포현황 요약

| 지표 | AWS | GCP |
|---|---|---|
| 코드 검토 기준 | 11개 구성·94개 선언 확인 | 대응 코드 보완, 코어 실제 적용·아래 차이 기록 |
| 전체 완료 기준을 검증한 구성 | 0/11 | 0/11 |
| 실제 자원 조회 | ❌ 전체 조회 미완료 | ✅ 최종 16종 조회·코어 생성/연결 시험 확인 |
| 동작 검증 완료 구성 | 0/11 | 0/11 |
| 선언별 대응 자원/기능 확인 | ❌ 0/94·실제 미확인 | ✅ 73/94 확인·❌ 21/94 미완료 |
| 실제 배포율 | 산정 불가 | 73/94는 대응 확인 수이며 전체 동등성/동작 완료율이 아님 |

위 0/11은 각 구성의 전체 완료 기준을 검증한 수입니다. 자원 생성 진행 상황은 구성별 상태와 아래 최신 배포 기록으로 보고합니다. 코어 연결 시험 통과는 전체 복구·권한 경계·알림 수신까지 완료했다는 뜻이 아닙니다. 부분 생성을 전체 동작 검증 완료로 세지 않습니다.

| AWS 구성 | 선언 수 | GCP 배포 대상 | 코드상 차이와 남은 일 | AWS 실제 상태 | GCP 실제 상태 |
|---|---:|---|---|---|---|
| network | 21 | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | 네트워크 코드 있음. 보안그룹별 허용·차단 의도와 라우터 경로·방화벽 기록 보완 | ❌ 미확인 | ✅ VPC·서브넷·NAT·사설 연결 / ❌ 전체 차단·경로 검증 |
| storage | 12 | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | 대응 코드 있음. AWS 로그 버킷 정책의 목적과 GCP 로그 쓰기 권한 대조 | ❌ 미확인 | ✅ 버킷·정책·6개 경로·워크로드 읽기 / ❌ 쓰기·비허용 접근 시험 |
| dns | 8 | Cloud DNS·도메인 인증·관리 인증서·이름 조회 기록 | 대응 코드 일부 있음. AWS 기본/와일드카드 인증서, 조회 로그·CAA 범위 대조 | ❌ 미확인 | ❌ 도메인·인증서 입력 대기 |
| database | 4 | Cloud SQL PostgreSQL 16·사설 연결·DB/사용자·백업·암호화 | 논리 디코딩·사설 암호화 접속 확인. 백업 복구·복제 동작 시험 필요 | ❌ 미확인 | ✅ 실행·사설 암호화 SELECT 1 / ❌ 복구·논리 복제 동작 시험 |
| alb | 5 | 예약 공개 주소·GKE Ingress·Service/NEG·상태 검사·HTTPS | Terraform+생성 설정 있음. 실제 LB는 GKE 컨트롤러가 생성, 앱 대상·상태 검사 경로 대조 | ❌ 미확인 | ✅ 주소·백엔드·외부 HTTP 200 / ❌ 도메인·HTTPS |
| observability | 11 | Cloud Logging/Monitoring·로그 내보내기·알람·이메일 | 대응 코드 일부 있음. 차단 통신·API/감사 로그 보관·여유 용량·NAT 포트 고갈·LB 자체 5xx 의미 대조 | ❌ 미확인 | ✅ 로그 내보내기 설정·정책 4개 / ❌ 이메일·발송/수신 시험 |
| eks | 14 | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | 드라이버·사양·버전·영역·볼륨 쓰기/읽기 확인. 재연결·권한 경계 시험 필요 | ❌ 미확인 | ✅ 3노드 Ready·볼륨 읽기/쓰기 / ❌ 재연결·권한 경계 시험 |
| eks-lbc | 3 | GKE 내장 부하분산 컨트롤러와 서비스 권한 | 별도 AWS 컨트롤러 역할을 GKE 관리 기능으로 대체. IAM 1:1 복제 대상 아님 | ❌ 미확인 | ✅ 관리형 컨트롤러·실제 LB 생성 / ❌ 권한 경계 검증 |
| eks-eso | 8 | Secret Manager·목적별 서비스 계정·Workload Identity·ESO 2개 | 권한/설치 코드 있음. 실제 비밀값·동기화·갱신·설치 소유권 사전 점검 필요 | ❌ 미확인 | ✅ 2개 설치·DB 동기화 / ❌ 앱/알림 비밀값·갱신/차단 시험 |
| msk | 3 | Google 관리형 Kafka·사설 연결·암호화/인증·토픽 설정 | 클러스터 코드 있음. SASL/OAuth 접속·토픽/복제 정책·최소 용량·실제 주소 대조 | ❌ 미확인 | ✅ ACTIVE·3브로커 인증·생산/소비 / ❌ 업무 토픽·지속 연결 시험 |
| tailscale | 5 | Compute Engine 사설 서브넷 라우터·전용 계정·Secret Manager·경로 | 별도 로컬 브랜치에 사설 라우터·키 참조 모듈 작성, 모의 검증 통과. 실제 키·경로 승인·서비스 연결 검증 필요 | ❌ 미확인 | ❌ 키 참조·테일넷·경로 승인 대기 |

## 공수 재산정

아래 수치는 전체 범위의 초기 추정입니다. 코어 배포를 마친 현재도 외부 입력 대기 및 복구·동등성 검증이 남아 있어 잔여 공수 확약으로 재사용하지 않습니다.

단위는 인시이며, 1명이 실제 작업하는 시간입니다. 기존 GCP 초안을 재사용하고 권한·프로젝트·비밀정보·도메인을 준비할 수 있다는 전제의 추정치입니다. 클라우드 과금액과 구분합니다.

| 작업 | 예상 인시 | 산출물 |
|---|---:|---|
| AWS/GCP 실제 상태·사양·소유권·상태 저장소 조사 | 3~5 | 양쪽 배포현황, 전체 선언/인스턴스 대응표, 입력값 |
| 기존 GCP 대응 보완: 복제·방화벽·알람·인증서·노드/DB/Kafka 차이 | 7~11 | 보완 코드·차이 결정·필요 검증 |
| Tailscale 사설 라우터·권한·경로 추가 | 4~6 | VM·비밀 참조·방화벽/경로 코드·연결 증거 |
| 구성/모의 검사·실제 계획·비용 검토·전체 적용 | 3~5 | 검토한 계획과 생성 결과, 실제 자원 목록 |
| ESO·Ingress·DB·Kafka·저장소·로그·알람·복구 통합 검증 | 7~11 | 성공/차단/알람 수신·복구 증거, 잔여 차이 |
| 체크리스트 갱신·변경 요청·Notion 초안·인계 | 4~6 | 근거가 연결된 양쪽 현황과 운영 절차 |
| **Terraform 기준 전체 인프라 합계** | **28~44** | **11개 구성에 대한 배포/검증 보고** |

- 1인 8시간 기준 순작업 약 3.5~5.5일입니다. 권한·할당량·도메인 위임·인증서 발급·팀 리뷰 대기는 별도이며, 달력상 완료일은 아직 확정하지 않습니다.
- 이전 답변에는 정량 공수가 없었으므로 증가율은 산정하지 않습니다. Kubernetes 전용 실행점 분리 작업은 제거하고 전체 구성 대응·검증 공수로 다시 계산했습니다.
- 별도 앱까지 동일 동작시키는 작업은 추가 **20~36인시**, 전체 **48~80인시**를 예비 범위로 봅니다. 해당 범위에는 review API/worker·Qdrant·샘플 앱·부하 장치·Prometheus/Grafana·배포 알림·단계적 배포의 GCP 연결, Kafka 인증·S3 호출 변경이 포함됩니다. 이 구성은 AWS Terraform 94개 선언의 분모에 넣지 않습니다. 본선 데이터 이전·전환·복귀 전체 시험은 별도 산정합니다.
- 추가 앱 공수는 애플리케이션 소스 점검 전의 낮은 신뢰도 추정입니다. 이 보고가 앱 저장소 수정을 승인하는 것은 아닙니다.
- 기존 노드 3대의 용량으로 부가 구성까지 수용 가능한지 자원 요청량을 합산합니다. 부족하면 임의 증설하지 않고 비용·사양 변경 승인을 요청합니다.
- 이 추정은 확약이 아닙니다. 1단계 실제 상태 조사 후 재사용 가능 자원·권한·서비스 제약에 따라 다시 갱신합니다.

## 주요 대응 차이와 결정할 사항

1. **네트워크/가용성**: AWS 서브넷은 두 가용 영역, GCP 초안은 리전 서브넷과 세 영역입니다. 내부/외부 경계와 총 노드 수를 유지하며 영역 배치 차이를 기록합니다. 공개 ALB 서브넷은 GCP 관리형 외부 부하분산 구조로 대응하며 같은 서브넷 수를 억지로 만들지 않습니다.
2. **Kubernetes 사양**: AWS 코드는 `t3.medium` 3대, 노드당 가상 프로세서 2개·메모리 4GiB·20GiB 디스크입니다. 초기의 `e2-medium`은 공유 코어 방식이므로 실제 배포는 `e2-custom-2-4096` 3대로 구성했습니다. AWS 실제 생존 자원 및 양쪽 비용·성능 대조는 남아 있습니다. 코어 수가 같아도 처리 성능이나 저장소 성능이 같다고 판정하지 않습니다. 버전은 실제 지원 교집합을 확인합니다.
3. **DB**: AWS PostgreSQL 16.15/`db.t4g.micro`/20~100GiB/백업 1일/사설 접속을 기준으로 비교합니다. GCP 초안 `db-custom-1-3840`은 자원 사양이 같지 않습니다. 지원 사양·복구·논리 디코딩을 포함해 가능한 최소 대응안을 정하고 차이를 남깁니다. 최신 AWS의 `rds.logical_replication`에 대응하는 `cloudsql.logical_decoding=on`을 이번 로컬 브랜치에 추가했습니다. 실제 활성 상태와 사설 암호화 접속은 확인했고, 복제 통신·백업 복구 시험은 남았습니다. [Cloud SQL 논리 복제](https://docs.cloud.google.com/sql/docs/postgres/replication/configure-logical-replication)
4. **DB 비밀번호**: RDS 관리형 비밀번호와 GCP의 외부 주입·Secret Manager 등록은 관리 방식이 다릅니다. 동기화·갱신·복구 방법을 검증하며 자동 회전까지 동일하다고 표시하지 않습니다.
5. **Kafka**: AWS는 브로커 2대와 각 20GiB, 사설 무인증 평문입니다. GCP 초안은 관리형 용량 설정과 암호화·토큰 인증입니다. 브로커 수·저장량·복제 정책의 직접 일치를 약속하지 않고 지원 제약을 기록합니다. 토픽·파티션과 생산/소비는 검증용 클라이언트로 시험합니다. 앱 호환성 수정은 별도입니다. 서울은 현재 서비스 지원 리전이나 프로젝트 할당량은 추가 확인합니다. [지원 리전](https://docs.cloud.google.com/managed-service-for-apache-kafka/docs/locations)
6. **인증서**: AWS 인증서는 기본 도메인과 와일드카드를 포함합니다. 현재 GCP 초안은 단일 앱 도메인만 처리합니다. 필요한 도메인 범위를 먼저 확인한 후 인증서 발급 방식과 Ingress/Gateway 연결 방식을 함께 설계합니다. 기본 LB 인증 방식의 인증서는 와일드카드를 지원하지 않으므로 단순 입력값 변경으로 완료 처리하지 않습니다. [인증서 동작](https://docs.cloud.google.com/certificate-manager/docs/certificate-selection-logic)
7. **로그/알람**: AWS 차단 흐름과 GCP의 샘플링한 서브넷 흐름 기록은 같지 않습니다. 방화벽 규칙 로깅까지 검토하고 허용/차단을 실제 시험합니다. DB 여유 공간 4GiB, NAT 포트 할당 오류, LB 자체 5xx 등 경보의 의미·기간·임계값을 대조합니다. 초안의 사용률·전체 드롭·모든 5xx 경보가 그대로 같은 것으로 계산되지 않습니다. [방화벽 차단 진단](https://docs.cloud.google.com/vpc/docs/access-flow-logs)
8. **사설 연결**: GCP Tailscale 라우터를 새로 만들고 온프렘에서 DB/Kafka 사설 주소까지 경로·이름 해석·정방향/반환 경로를 시험합니다. Cloud SQL 사설 서비스 연결과 Kafka 서비스 네트워크를 동일한 VPC 경로로 가정하지 않습니다. 필요한 피어링 경로 내보내기·서비스 경로 접근 방식을 확인합니다. Tailscale 관리자의 키/태그/경로 승인이 선행 조건입니다.
9. **컨트롤러**: AWS 부하분산 컨트롤러의 전용 IAM 역할은 GKE 관리형 기능으로 대체합니다. 별도 IAM 리소스가 없더라도 기능과 접근 경계 증거가 있으면 대응으로 처리할 수 있습니다.
10. **앱 범위**: Terraform의 자원 생성과 GitOps 앱의 실행을 구분합니다. 공개 부하분산 기능·시크릿·DB/Kafka 접속을 시험하는 최소 검증 구성은 기본 공수에 포함하되 기존 앱의 전체 이식과 운영 전환은 보조 목록으로 따로 관리합니다.

## 상태 표시와 갱신 규칙

- 코드 상태: `AWS 선언 확인`, `GCP 대응 코드 확인`, `보완 필요`, `신규 필요`, `관리형 기능 대체`.
- 실제 상태: `미확인`, `미배포 확인`, `일부 배포`, `배포됨·검증 대기`, `배포·검증 완료`, `차이 승인 대기`, `확인된 장애/권한 제한`.
- 표시는 **✅ 확인 완료 / ❌ 확인 미완료**로 통일합니다. 반드시 `미확인`, `미배포 확인`, `일부 배포`, `배포됨·검증 대기` 등의 상태를 함께 적습니다. **❌ 미확인은 미배포나 장애를 뜻하지 않습니다.** 배포 확인 열은 실제 배포 증거가 있을 때만 ✅로 바꾸며, 동작 검증 결과는 상태/증거 열에 따로 기록합니다.
- 여러 인스턴스가 있는 선언은 전부 확인해야 선언 전체를 체크합니다. 일부만 확인되면 `일부 배포(확인 n/예상 m)`로 씁니다.
- 의도적으로 생성하지 않는 조건부 자원은 `해당 없음(조건·승인 근거)`으로 표기하고 미완료에 묻어 두지 않습니다. 분모 조정은 적용한 입력/실제 계획과 연결해 기록합니다.
- 관리형 기능으로 대체하는 경우 GCP 자원/기능 식별자와 검증 근거를 남깁니다. AWS 자원 개수와 GCP 자원 개수를 맞추지 않습니다.
- 증거 최소 필드: 확인 시각(한국시간), 계정/프로젝트·리전, 자원 ID, 선언/실제 인스턴스 주소, 상태 조회 또는 검증 명령과 결과, 비밀값을 제거한 결과 파일/링크, 확인자.
- AWS/GCP 상태와 검증은 각각 갱신합니다. Terraform 상태에만 존재하는 자원을 실제 배포됨으로 단정하지 않고 클라우드 조회와 대조합니다.
- 변경은 확인 시점마다, Slack 보고는 의미 있는 진행·차이·장애 발견 시 같은 날짜 글 댓글로 남깁니다. 자동 주기 보고나 예약 작업은 만들지 않습니다.
- Slack 보고 형식: `기준 커밋 / 조사·생성·검증 단계 / AWS 확인 a/11·미확인 b/11 / GCP 확인 c/11·미확인 d/11 / 이번 변화·근거 / 남은 일·다음 단계`.
- 비용은 GKE 노드/제어 영역·임시 노드·SQL·Kafka·NAT·공개 주소/LB·라우터 VM·저장소·로그·네트워크 전송을 포함해 산정합니다. 아직 과금액을 계산하지 않았습니다.

## 사용자가 제공하거나 결정할 정보

| 시점 | 정보 | 제공할 내용 | 현재 상태 |
|---|---|---|---|
| 조사 시작 전 | GCP 대상 | `ghost-project-513812`, 표시명 `ghost-project`, 프로젝트 번호 `251118972904` | ✅ 사용자 지정·브라우저 확인 |
| 조사 시작 전 | AWS/GCP 접근 방법 | 브라우저 로그인 제공. GCP 프로젝트 확인, AWS 계정 `974402993422`·`GhostInfraEngineer` 확인 | ✅ GCP 명령줄 인증 완료 / ❌ AWS 자원 세션 갱신 필요 |
| 실제 배포 전 | 예산·사용 기간 | 월 또는 총비용 상한, 사용 종료일·철거 방침 | ❌ 미확인 |
| 실제 배포 전 | 기존 GCP 자원 처리 | 재사용할 자원·프로젝트가 있으면 지정. 없으면 먼저 조회하고 신규/재사용안을 제시 | ✅ 사전 조회 후 전용 자원 신규 생성 |
| 도메인/인증서 구성 전 | 도메인·관리 가능 여부 | GCP 전용 호스트명 또는 하위 도메인, DNS 관리 경로 | ❌ 미확인 |
| 알림 연결 전 | 수신 이메일 | 운영 알림을 받을 주소 | ❌ 미확인 |
| 사설 연결 검증 전 | Tailscale 관리 경로 | 사용할 테일넷·태그/경로/키 승인을 받을 관리자. 비밀 키는 채팅 대신 비밀 저장소에서 주입 | ❌ 미확인 |

결제 연결·권한·할당량·기존 자원 목록·AWS 실제 사양·상태 저장소·공인 출구 주소·주소 충돌은 접근이 준비되면 조회합니다. 비밀값의 준비 여부와 참조 위치는 확인하되, 비밀번호·인증 키 원문을 이 문서에 적지 않습니다.

## 사전 준비 체크리스트

아래 항목은 AWS Terraform의 `data`·backend 또는 코드 밖 준비물이며 94개 선언 수와 구분합니다.

| ID | 확인할 사항 | AWS | GCP | 증거/상태 |
|---|---|---|---|---|
| PRE-01 | 대상 계정/프로젝트·결제·허용 리전·배포자 권한 | ❌ 권한 조회 미완료 | ✅ 계정·결제·권한·리전 확인 | 사용자 승인 역할 반영, 실제 적용 성공 |
| PRE-02 | 상태 저장소·버전 보존·잠금·실제 원격 상태 접근 | ❌ 미확인 | ✅ 원격 상태 접근·재계획0 | 버전 관리·공개 차단·전용 상태 |
| PRE-03 | 관리자·자동 배포 주체와 접속 허용 출구 주소 | ❌ 미확인 | ✅ 승인된 사용자 관리자·전체 주소 허용 | 자동 배포 주체 별도 미구성 |
| PRE-04 | DB·GitOps·검토 서비스·Tailscale의 비밀 참조와 키 준비 | ❌ 미확인 | ✅ DB 비밀 준비 / ❌ 앱·GitOps·Tailscale | DB만 동기화 Ready |
| PRE-05 | 도메인 소유·DNS 위임·알림 이메일 | ❌ 미확인 | ❌ 입력 대기 | 도메인·위임·수신 이메일 미제공 |
| PRE-06 | 노드·SQL·Kafka·IP/디스크 할당량과 기존 자원 소유권 | ❌ 미확인 | ✅ 사전 할당량·최종 자원 조회 | 코어 실제 생성·16종 최종 조회 |
| PRE-07 | Tailscale 태그·키·경로 승인·온프렘 경로 수신 | ❌ 미확인 | ❌ 입력 대기 | 키 참조·테일넷·경로 승인 미제공 |

## Terraform 리소스별 배포 체크리스트

AWS 선언 94개를 빠짐없이 추적합니다. GCP 대응 대상 열은 계획이며 배포 완료 표시가 아닙니다.

### network

완료 기준: 허용/차단 통신, 사설 노드 외부 다운로드, 주소 중복·경로 검사.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| NETWORK-01 | [aws_vpc.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | oneaction-dev-vpc 조회 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-02 | [aws_subnet.public_2a](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | 외부 LB 관리형 네트워크로 대체, 공개 서브넷 별도 생성 없음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-03 | [aws_subnet.public_2c](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | 외부 LB 관리형 네트워크로 대체, 공개 서브넷 별도 생성 없음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-04 | [aws_subnet.eks_2a](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | 리전 GKE 서브넷10.20.32.0/19, 3영역 공유 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-05 | [aws_subnet.eks_2c](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | 리전 GKE 서브넷10.20.32.0/19, 3영역 공유 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-06 | [aws_subnet.data_2a](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | 리전 data 서브넷10.20.10.0/24 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-07 | [aws_subnet.data_2c](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | 리전 data 서브넷10.20.10.0/24 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-08 | [aws_internet_gateway.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | Google 관리형 인터넷 게이트웨이·기본 경로 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-09 | [aws_eip.nat](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ❌ 미완료 | Cloud NAT 자동 주소 사용; AWS 고정 EIP와 다름 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-10 | [aws_nat_gateway.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | oneaction-dev-nat; 사설 노드 다운로드 성공 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-11 | [aws_route_table.public](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | VPC 기본·서브넷·피어링 경로로 대체; 전체 허용/차단 검증은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-12 | [aws_route.public_default](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | VPC 기본·서브넷·피어링 경로로 대체; 전체 허용/차단 검증은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-13 | [aws_route_table_association.public_2a](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | VPC 기본·서브넷·피어링 경로로 대체; 전체 허용/차단 검증은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-14 | [aws_route_table_association.public_2c](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | VPC 기본·서브넷·피어링 경로로 대체; 전체 허용/차단 검증은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-15 | [aws_route_table.private](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | VPC 기본·서브넷·피어링 경로로 대체; 전체 허용/차단 검증은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-16 | [aws_route.private_default](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | VPC 기본·서브넷·피어링 경로로 대체; 전체 허용/차단 검증은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-17 | [aws_route_table_association.private](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | VPC 기본·서브넷·피어링 경로로 대체; 전체 허용/차단 검증은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-18 | [aws_vpc_endpoint.s3](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | Private Google Access 등 사설 Google API 접근으로 대응 | ❌ 미확인 | ✅ 대응 배포 확인 | Private Google Access 활성·GCS 워크로드 읽기 성공 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-19 | [aws_security_group.alb](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 생성 방화벽·백엔드 HEALTHY·외부 HTTP 200 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-20 | [aws_security_group.eks_node_extra](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ❌ 미완료 | GKE 관리 규칙 존재; AWS 추가 노드 규칙 동등성 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| NETWORK-21 | [aws_security_group.rds](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/network/main.tf) | VPC·리전 서브넷·Cloud Router/NAT·Private Google Access·방화벽 | ❌ 미확인 | ❌ 미완료 | Cloud SQL 사설 주소·암호화 접속 성공; AWS SG 경계 동등성 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

### storage

완료 기준: 허용 주체 읽기/쓰기, 비허용 접근 차단, 객체 버전·보관 정책.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| STORAGE-01 | [aws_s3_bucket.review_docs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-02 | [aws_s3_bucket_ownership_controls.review_docs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-03 | [aws_s3_bucket_public_access_block.review_docs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-04 | [aws_s3_bucket_versioning.review_docs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-05 | [aws_s3_bucket_server_side_encryption_configuration.review_docs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-06 | [aws_s3_object.review_prefixes](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-07 | [aws_s3_bucket.logs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-08 | [aws_s3_bucket_ownership_controls.logs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-09 | [aws_s3_bucket_public_access_block.logs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-10 | [aws_s3_bucket_server_side_encryption_configuration.logs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-11 | [aws_s3_bucket_lifecycle_configuration.logs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| STORAGE-12 | [aws_s3_bucket_policy.logs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/storage/main.tf) | Cloud Storage 문서·로그 버킷, 권한·공개 차단·버전·수명주기 | ❌ 미확인 | ✅ 대응 배포 확인 | 문서/로그 버킷 실조회: 공개 차단·통합 권한·버전/30일 수명주기·6경로, 로그 쓰기 계정. 읽기 시험 성공, 쓰기/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

### dns

완료 기준: 도메인 위임·조회·인증서 유효성·갱신 경로와 조회 기록.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| DNS-01 | [aws_route53_zone.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/dns/main.tf) | Cloud DNS·도메인 인증·관리 인증서·이름 조회 기록 | ❌ 미확인 | ❌ 미완료 | 도메인·위임 정보 미제공; 인증서/레코드 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| DNS-02 | [aws_acm_certificate.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/dns/main.tf) | 관리 인증서: AWS 와일드카드 포함 범위와 발급 방식 재설계 필요 | ❌ 미확인 | ❌ 미완료 | 도메인·위임 정보 미제공; 인증서/레코드 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| DNS-03 | [aws_route53_record.certificate_validation](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/dns/main.tf) | 도메인 인증 레코드: 인증서 방식에 따라 대응 | ❌ 미확인 | ❌ 미완료 | 도메인·위임 정보 미제공; 인증서/레코드 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| DNS-04 | [aws_acm_certificate_validation.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/dns/main.tf) | 선정한 인증서 방식의 도메인 소유 확인·발급 완료 검사 | ❌ 미확인 | ❌ 미완료 | 도메인·위임 정보 미제공; 인증서/레코드 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| DNS-05 | [aws_route53_record.caa](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/dns/main.tf) | Cloud DNS·도메인 인증·관리 인증서·이름 조회 기록 | ❌ 미확인 | ❌ 미완료 | 도메인·위임 정보 미제공; 인증서/레코드 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| DNS-06 | [aws_cloudwatch_log_group.route53_queries](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/dns/main.tf) | Cloud DNS·도메인 인증·관리 인증서·이름 조회 기록 | ❌ 미확인 | ❌ 미완료 | 도메인·위임 정보 미제공; 인증서/레코드 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| DNS-07 | [aws_cloudwatch_log_resource_policy.route53_query_logs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/dns/main.tf) | Cloud DNS·도메인 인증·관리 인증서·이름 조회 기록 | ❌ 미확인 | ❌ 미완료 | 도메인·위임 정보 미제공; 인증서/레코드 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| DNS-08 | [aws_route53_query_log.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/dns/main.tf) | Cloud DNS 조회 로그 활성화·조회 검증 | ❌ 미확인 | ❌ 미완료 | 도메인·위임 정보 미제공; 인증서/레코드 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

### database

완료 기준: 암호화 접속·권한·읽기/쓰기·논리 복제 설정·백업/복구 검사.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| DATABASE-01 | [aws_db_subnet_group.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/database/main.tf) | Cloud SQL 사설 서비스 연결/네트워크로 기능 대응 | ❌ 미확인 | ✅ 대응 배포 확인 | 사설 서비스 연결·10.20.128.3 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| DATABASE-02 | [aws_db_parameter_group.postgres16](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/database/main.tf) | Cloud SQL 플래그: 강제 암호화 + cloudsql.logical_decoding 대응 보완 | ❌ 미확인 | ✅ 대응 배포 확인 | PostgreSQL16·logical_decoding=on 실조회 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| DATABASE-03 | [aws_cloudwatch_log_group.postgresql](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/database/main.tf) | Cloud SQL PostgreSQL 16·사설 연결·DB/사용자·백업·암호화 | ❌ 미확인 | ✅ 대응 배포 확인 | Cloud SQL 관리형 로깅·로그 sink 구성; 실제 내보내기 검증 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| DATABASE-04 | [aws_db_instance.review](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/database/main.tf) | Cloud SQL 인스턴스·DB·사용자·백업/암호화/용량 | ❌ 미확인 | ✅ 대응 배포 확인 | RUNNABLE·db-custom-1-3840·백업 활성·사설 암호화 SELECT 1; 복구 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

### alb

완료 기준: 백엔드 정상·HTTP/HTTPS·대상 포트·오류 응답·접근 로그.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| ALB-01 | [aws_lb.platform](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/alb/main.tf) | 예약 공개 주소·GKE Ingress·Service/NEG·상태 검사·HTTPS | ❌ 미확인 | ✅ 대응 배포 확인 | 34.149.47.248·GKE Ingress 생성 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| ALB-02 | [aws_lb_target_group.platform](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/alb/main.tf) | 예약 공개 주소·GKE Ingress·Service/NEG·상태 검사·HTTPS | ❌ 미확인 | ✅ 대응 배포 확인 | NEG 백엔드 HEALTHY·임시 앱 외부 HTTP 200. 시험 앱은 정리함 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| ALB-03 | [aws_lb_listener.https](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/alb/main.tf) | 예약 공개 주소·GKE Ingress·Service/NEG·상태 검사·HTTPS | ❌ 미확인 | ❌ 미완료 | 도메인 미제공으로 HTTPS 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| ALB-04 | [aws_lb_listener.http](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/alb/main.tf) | 예약 공개 주소·GKE Ingress·Service/NEG·상태 검사·HTTPS | ❌ 미확인 | ✅ 대응 배포 확인 | HTTP 80 경로 검증. HTTPS 리다이렉트는 아직 없음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| ALB-05 | [aws_route53_record.app](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/alb/main.tf) | 예약 공개 주소·GKE Ingress·Service/NEG·상태 검사·HTTPS | ❌ 미확인 | ❌ 미완료 | 도메인 미제공으로 A 레코드 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

### observability

완료 기준: 기록 발생·보관·내보내기, 알람 조건·수신까지 확인.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| OBSERVABILITY-01 | [aws_cloudwatch_log_group.vpc_flow](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | Cloud Logging/Monitoring·로그 내보내기·알람·이메일 | ❌ 미확인 | ✅ 대응 배포 확인 | 로그 설정·sink/작성자와 경보 4개 실조회; 알림 수신·로그 내보내기 결과 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| OBSERVABILITY-02 | [aws_cloudwatch_log_group.eks_cluster](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | GKE 제어 영역/API·감사 로그와 AWS 7일 보관 의도 대조 | ❌ 미확인 | ✅ 대응 배포 확인 | 로그 설정·sink/작성자와 경보 4개 실조회; 알림 수신·로그 내보내기 결과 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| OBSERVABILITY-03 | [aws_iam_role.flow_logs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | Cloud Logging/Monitoring·로그 내보내기·알람·이메일 | ❌ 미확인 | ✅ 대응 배포 확인 | 로그 설정·sink/작성자와 경보 4개 실조회; 알림 수신·로그 내보내기 결과 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| OBSERVABILITY-04 | [aws_iam_role_policy.flow_logs](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | Cloud Logging/Monitoring·로그 내보내기·알람·이메일 | ❌ 미확인 | ✅ 대응 배포 확인 | 로그 설정·sink/작성자와 경보 4개 실조회; 알림 수신·로그 내보내기 결과 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| OBSERVABILITY-05 | [aws_flow_log.rejects](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | 방화벽 허용/차단 기록: VPC Flow Logs만으로 동일 판정하지 않음 | ❌ 미확인 | ✅ 대응 배포 확인 | 명시적 기본 차단 방화벽에 로깅 활성; 실제 차단 로그 발생·검색 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| OBSERVABILITY-06 | [aws_sns_topic.alerts](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | Cloud Logging/Monitoring·로그 내보내기·알람·이메일 | ❌ 미확인 | ❌ 미완료 | 수신 이메일 미제공; 대응 이메일 채널 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| OBSERVABILITY-07 | [aws_sns_topic_subscription.email](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | Cloud Logging/Monitoring·로그 내보내기·알람·이메일 | ❌ 미확인 | ❌ 미완료 | 수신 이메일 미제공; 대응 이메일 채널 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| OBSERVABILITY-08 | [aws_cloudwatch_metric_alarm.alb_5xx](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | GCP LB 자체 오류 경보: 현재 모든 5xx 집계와 의미 차이 보완 | ❌ 미확인 | ✅ 대응 배포 확인 | 로그 설정·sink/작성자와 경보 4개 실조회; 알림 수신·로그 내보내기 결과 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| OBSERVABILITY-09 | [aws_cloudwatch_metric_alarm.rds_cpu](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | Cloud Logging/Monitoring·로그 내보내기·알람·이메일 | ❌ 미확인 | ✅ 대응 배포 확인 | 로그 설정·sink/작성자와 경보 4개 실조회; 알림 수신·로그 내보내기 결과 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| OBSERVABILITY-10 | [aws_cloudwatch_metric_alarm.rds_free_storage](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | Cloud SQL 여유 디스크 용량 경보: 현재 사용률 80%와 의미 차이 보완 | ❌ 미확인 | ✅ 대응 배포 확인 | 로그 설정·sink/작성자와 경보 4개 실조회; 알림 수신·로그 내보내기 결과 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| OBSERVABILITY-11 | [aws_cloudwatch_metric_alarm.nat_error_port_allocation](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/observability/main.tf) | Cloud NAT 포트 부족 경보: 현재 전체 드롭 패킷 경보와 차이 보완 | ❌ 미확인 | ✅ 대응 배포 확인 | 로그 설정·sink/작성자와 경보 4개 실조회; 알림 수신·로그 내보내기 결과 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

### eks

완료 기준: 노드 수/사양·Ready·접근 제한·이름 해석·통신·영구 볼륨 재연결.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| EKS-01 | [aws_eks_access_entry.admin](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/access.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-02 | [aws_eks_access_policy_association.admin](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/access.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-03 | [aws_eks_addon.networking](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/addons.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-04 | [aws_eks_addon.runtime](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/addons.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-05 | [aws_eks_cluster.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/cluster.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-06 | [aws_iam_role.ebs_csi](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/ebs-csi.tf) | GCP 디스크 드라이버 권한/관리 주체로 기능 대응 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-07 | [aws_iam_role_policy_attachment.ebs_csi](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/ebs-csi.tf) | GCP 디스크 드라이버에 필요한 실제 권한 검사 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-08 | [aws_eks_addon.ebs_csi](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/ebs-csi.tf) | GCE Persistent Disk CSI 드라이버·StorageClass·영구 볼륨 검증 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-09 | [aws_iam_role.cluster](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/iam.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-10 | [aws_iam_role_policy_attachment.cluster](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/iam.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-11 | [aws_iam_role.node](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/iam.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-12 | [aws_iam_role_policy_attachment.node](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/iam.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-13 | [aws_launch_template.node](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/node-group.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-14 | [aws_eks_node_group.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks/node-group.tf) | GKE Standard·노드 풀·관리자/노드 계정·내장 네트워크/인증·디스크 드라이버 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 관리형 기능·전용 노드 계정·승인된 관리자 역할. 3노드 Ready, 2CPU/4GiB/20GiB, 디스크 쓰기/읽기 성공; 재연결·권한 경계 미검증 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

### eks-lbc

완료 기준: 실제 Ingress 반영·상태 검사·컨트롤러 동작·권한 경계.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| EKS-LBC-01 | [aws_iam_role.controller](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-lbc/main.tf) | GKE 내장 부하분산 컨트롤러와 서비스 권한 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 내장 컨트롤러로 IAM/연결 대체. 실제 Ingress·상태 검사·외부 HTTP 200; 권한 경계 시험 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-LBC-02 | [aws_iam_role_policy.controller](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-lbc/main.tf) | GKE 내장 부하분산 컨트롤러와 서비스 권한 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 내장 컨트롤러로 IAM/연결 대체. 실제 Ingress·상태 검사·외부 HTTP 200; 권한 경계 시험 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-LBC-03 | [aws_eks_pod_identity_association.controller](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-lbc/main.tf) | GKE 내장 부하분산 컨트롤러와 서비스 권한 | ❌ 미확인 | ✅ 대응 배포 확인 | GKE 내장 컨트롤러로 IAM/연결 대체. 실제 Ingress·상태 검사·외부 HTTP 200; 권한 경계 시험 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

### eks-eso

완료 기준: 허용 비밀만 동기화·불필요한 비밀 차단·갱신 반영·알림용 키 분리.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| EKS-ESO-01 | [aws_iam_role_policy.read_gitops](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-eso/gitops-secret.tf) | Secret Manager·목적별 서비스 계정·Workload Identity·ESO 2개 | ❌ 미확인 | ✅ 대응 배포 확인 | 목적별 서비스 계정·비밀별 권한 생성, 운영자 2개 설치. DB만 Ready, 앱/알림 비밀값·갱신/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-ESO-02 | [aws_iam_role.eso](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-eso/main.tf) | Secret Manager·목적별 서비스 계정·Workload Identity·ESO 2개 | ❌ 미확인 | ✅ 대응 배포 확인 | 목적별 서비스 계정·비밀별 권한 생성, 운영자 2개 설치. DB만 Ready, 앱/알림 비밀값·갱신/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-ESO-03 | [aws_iam_role_policy.read_rds](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-eso/main.tf) | Secret Manager·목적별 서비스 계정·Workload Identity·ESO 2개 | ❌ 미확인 | ✅ 대응 배포 확인 | 목적별 서비스 계정·비밀별 권한 생성, 운영자 2개 설치. DB만 Ready, 앱/알림 비밀값·갱신/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-ESO-04 | [aws_eks_pod_identity_association.eso](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-eso/main.tf) | Secret Manager·목적별 서비스 계정·Workload Identity·ESO 2개 | ❌ 미확인 | ✅ 대응 배포 확인 | 목적별 서비스 계정·비밀별 권한 생성, 운영자 2개 설치. DB만 Ready, 앱/알림 비밀값·갱신/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-ESO-05 | [aws_iam_role.notifications](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-eso/notifications.tf) | Secret Manager·목적별 서비스 계정·Workload Identity·ESO 2개 | ❌ 미확인 | ✅ 대응 배포 확인 | 목적별 서비스 계정·비밀별 권한 생성, 운영자 2개 설치. DB만 Ready, 앱/알림 비밀값·갱신/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-ESO-06 | [aws_iam_role_policy.read_notifications](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-eso/notifications.tf) | Secret Manager·목적별 서비스 계정·Workload Identity·ESO 2개 | ❌ 미확인 | ✅ 대응 배포 확인 | 목적별 서비스 계정·비밀별 권한 생성, 운영자 2개 설치. DB만 Ready, 앱/알림 비밀값·갱신/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-ESO-07 | [aws_eks_pod_identity_association.notifications](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-eso/notifications.tf) | Secret Manager·목적별 서비스 계정·Workload Identity·ESO 2개 | ❌ 미확인 | ✅ 대응 배포 확인 | 목적별 서비스 계정·비밀별 권한 생성, 운영자 2개 설치. DB만 Ready, 앱/알림 비밀값·갱신/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| EKS-ESO-08 | [aws_iam_role_policy.read_review_service](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/eks-eso/review-service-secret.tf) | Secret Manager·목적별 서비스 계정·Workload Identity·ESO 2개 | ❌ 미확인 | ✅ 대응 배포 확인 | 목적별 서비스 계정·비밀별 권한 생성, 운영자 2개 설치. DB만 Ready, 앱/알림 비밀값·갱신/차단 시험은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

### msk

완료 기준: 인증·생산/소비·토픽 설정·연결 지속·실제 용량/서비스 제약 기록.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| MSK-01 | [aws_security_group.msk](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/msk/main.tf) | Google 관리형 Kafka·사설 연결·암호화/인증·토픽 설정 | ❌ 미확인 | ✅ 대응 배포 확인 | 사설 PSC 접속·SASL_SSL/OAuth 인증 성공; AWS SG와 관리 방식 다름 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| MSK-02 | [aws_msk_configuration.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/msk/main.tf) | Kafka 토픽·복제·파티션·자동 생성 정책: 서비스 허용 범위에서 대응 | ❌ 미확인 | ❌ 미완료 | 임시 토픽 복제3/min.insync2 송수신 성공 후 삭제. 업무 토픽·AWS 클러스터 정책 대응은 남음 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| MSK-03 | [aws_msk_cluster.this](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/msk/main.tf) | Google 관리형 Kafka·사설 연결·암호화/인증·토픽 설정 | ❌ 미확인 | ✅ 대응 배포 확인 | ACTIVE·4vCPU/4GiB·3브로커 인증·메시지 송수신 성공 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

### tailscale

완료 기준: 온프렘→허용 DB/Kafka 통신·비허용 차단·재시작 후 경로/인증 유지.

| ID | AWS Terraform 선언 | GCP 대응 대상 | AWS 배포 확인 | GCP 배포 확인 | 상태/증거 |
|---|---|---|---|---|---|
| TAILSCALE-01 | [aws_iam_role.router](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/tailscale/main.tf) | Compute Engine 사설 서브넷 라우터·전용 계정·Secret Manager·경로 | ❌ 미확인 | ❌ 미완료 | enable_tailscale=false인 코어 단계. 키 참조·테일넷·경로 승인 미제공으로 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| TAILSCALE-02 | [aws_iam_role_policy.read_auth_key](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/tailscale/main.tf) | 라우터 전용 Secret Manager 비밀 읽기 권한 신규 구현 | ❌ 미확인 | ❌ 미완료 | enable_tailscale=false인 코어 단계. 키 참조·테일넷·경로 승인 미제공으로 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| TAILSCALE-03 | [aws_iam_instance_profile.router](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/tailscale/main.tf) | Compute Engine 인스턴스 서비스 계정 연결로 대응 | ❌ 미확인 | ❌ 미완료 | enable_tailscale=false인 코어 단계. 키 참조·테일넷·경로 승인 미제공으로 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| TAILSCALE-04 | [aws_security_group.router](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/tailscale/main.tf) | Compute Engine 사설 서브넷 라우터·전용 계정·Secret Manager·경로 | ❌ 미확인 | ❌ 미완료 | enable_tailscale=false인 코어 단계. 키 참조·테일넷·경로 승인 미제공으로 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |
| TAILSCALE-05 | [aws_instance.router](https://github.com/SoftBankHackathon2026/oneaction-infra/blob/0c94c0141588934dee0e306b3f7ebb355f2a33d8/infra/tailscale/main.tf) | 사설 라우터 VM·IP forwarding·Tailscale·재시작 복구 신규 구현 | ❌ 미확인 | ❌ 미완료 | enable_tailscale=false인 코어 단계. 키 참조·테일넷·경로 승인 미제공으로 미배포 / [최신 근거](evidence/ghost-project-deployment-2026-11-06.json) |

## 설치와 기능 검증 보조 체크리스트

AWS Terraform이 IAM/연결 기반만 만드는 구성도 있어 실제 인프라 사용 가능 여부는 아래 설치까지 확인합니다. 이 목록은 94개 선언과 별도입니다.

| ID | 항목 | AWS | GCP | 통과 기준 |
|---|---|---|---|---|
| INT-01 | 부하분산 컨트롤러/관리형 기능 | ❌ 미확인 | ✅ HTTP·관리형 LB / ❌ HTTPS | 올바른 대상의 Ingress와 외부 상태 검사·HTTPS 정상 |
| INT-02 | ESO 플랫폼/알림 설치·SecretStore·동기화 | ❌ 미확인 | ✅ DB 동기화 / ❌ 앱·갱신·차단 | 필요한 키 동기화, 비허용 키 차단, 갱신 확인 |
| INT-03 | 영구 디스크 드라이버·StorageClass | ❌ 미확인 | ✅ 생성·쓰기·읽기 / ❌ 재연결 | 볼륨 생성/읽기/쓰기·Pod 재생성 후 재연결 |
| INT-04 | DB 암호화 접속·논리 디코딩·백업 복구 | ❌ 미확인 | ✅ 암호화 SELECT·설정 / ❌ 복구 | 필요한 설정과 테스트 데이터 복구 일치 |
| INT-05 | Kafka 인증·토픽·생산/소비 | ❌ 미확인 | ✅ 인증·송수신 / ❌ 비허용 거절 | 테스트 메시지 성공, 비허용 접속 거절 |
| INT-06 | 온프렘→사설 DB/Kafka | ❌ 미확인 | ❌ Tailscale 미배포 | 이름 해석·접근·반환 경로·라우터 재시작 후 유지 |
| INT-07 | 로그·알람·메일 | ❌ 미확인 | ✅ 로그·경보 생성 / ❌ 내보내기·수신 | 실제 로그 검색·내보내기·안전한 시험 알림 수신 |
| INT-08 | 계획 재실행·실패 복구·정리 | ❌ 미확인 | ✅ 재계획0·임시 정리 / ❌ 상태 복구 시험 | 예상 외 변경 없음, 상태 복구·보존/삭제 정책 검토 |

## 애플리케이션 별도 범위 체크리스트

AWS 앱 실제 상태는 미확인이며, 이번 GCP에는 업무 앱을 배포하지 않았습니다. 아래는 추가 작업 범위입니다. 과거 GitOps 선언과 문서를 현재 배포 증거로 사용하지 않습니다.

- ❌ Argo CD/Argo Rollouts의 실행 위치·등록·인증·알림 소유권 확인
- ❌ review API/worker·Qdrant의 GCP 배포와 설정/권한
- ❌ 샘플 앱·부하 생성·Prometheus/Grafana·대시보드
- ❌ Cloud SQL 프록시·Kafka 토큰 갱신·Cloud Storage 호출 호환성
- ❌ 배포 결과 기록·알림 수신·자동 단계적 배포 실패/복구

## 적용과 복구 순서

1. 양쪽 현재 자원·상태·소유권을 조회하고 체크리스트의 미확인을 갱신합니다.
2. 차이·권한·입력·비용·실제 지원을 확인하고 필요한 코드 보완과 관련 검증을 수행합니다.
3. bootstrap 상태 저장소를 준비하고 버전·잠금·복구 경로를 확인합니다.
4. 검토한 전체 계획에 따라 네트워크·저장소·DB/Kafka·계정·GKE·주소/DNS/알람을 의존 순서대로 적용합니다. AWS 폴더 적용 순서를 GCP 통합 실행점에 그대로 복사하지 않습니다.
5. 비밀정보와 Tailscale 승인을 연결하고 ESO·Ingress·영구 디스크 등 기능을 검증합니다.
6. 자원별 실제 상태와 기능 검증 증거를 기록하고 재계획의 예상 외 변경을 확인합니다.
7. 실패 시 로그·현재 상태를 보존하고 신규/기존 자원을 분리합니다. 기존 자원/공용 상태/비밀정보를 일괄 삭제하지 않습니다.
8. 철거 시 Ingress가 만든 LB 등 Kubernetes 소유 자원을 먼저 처리하고 DB·객체·볼륨 보존/백업을 확인합니다. 삭제 보호 해제와 영구 삭제는 필요한 명시적 승인을 받은 뒤 검토한 삭제 계획으로 진행합니다. 상태 저장소는 별도로 보존합니다.

## 변경 이력

| 날짜 | 변경 | 실제 상태 변화 |
|---|---|---|
| 2026-11-05 | Kubernetes 우선 계획을 AWS 전체 Terraform 대응으로 정정. 11개 구성·94개 선언 체크리스트와 28~44인시 추정 작성 | 당시 양쪽 미확인. 코드/자원 생성 없음 |
| 2026-11-05 | softbank-ghost 프로젝트·결제 미연결·GKE API 미활성화 확인. 별도 브랜치에 라우터·논리 디코딩·드라이버·로그/알람 보완 및 읽기 전용 조회 도구 작성 | Terraform 모의 17개·Python 16개 통과. 실제 계획/적용/전체 자원 조회 미완료 |

| 2026-11-05 | 사용자 승인 후 GitHub 명령줄 도구로 초안 #3 제목·본문 수정 및 저장 결과 확인. Slack 추가 인증 절차 중단 지시 반영 | 초안·미병합 유지. 실제 계획/적용 없음 |

| 2026-11-05 | 사용자가 새 대상 ghost-project 지정. 실제 ID ghost-project-513812·번호 251118972904 및 해커톤 결제 연결 확인 | 프로젝트·결제 ✅. 실행 인증·실제 계획/적용 ❌ |

## 배포 착수 후 확인 결과

| 항목 | 상태 | 근거 |
|---|---|---|
| 대상 GCP 프로젝트 | ✅ 확인 | 사용자 지시로 변경. 브라우저 시작 화면: ghost-project-513812 / 251118972904 |
| GCP 결제 연결 | ✅ 연결 확인 | [연결된 계정 화면](https://console.cloud.google.com/billing/linkedaccount?authuser=1&project=ghost-project-513812)에 ‘해커톤 결제’ 연결 표시 |
| GKE 및 필수 API | ✅ 활성화 | 지정된 12개 필수 서비스 활성화와 Terraform 상태 편입 수행 |
| AWS 계정·역할 | ✅ 확인 | 액세스 포털/콘솔: 974402993422 / GhostInfraEngineer |
| AWS 실제 자원 | ❌ 미확인 | 자원 화면 진입 시 로그인 재요구. 계정 확인을 자원 배포 증거로 사용하지 않음 |
| GCP 명령줄 인증 | ✅ 완료 | 사용자의 명시적 승인 후 Google 공식 배포 도구 로그인·실제 프로젝트 조회 성공 |
| 로컬 코드 보완 | ✅ 초안 작성 | [작업 폴더](../) / infra/gcp-full-deployment 브랜치. AWS 파일 무변경 |
| 로컬 검증 | ✅ 통과 | Terraform 모의 20개 통과, Python 기존 16개 통과, 형식·공백 검사 |
| 원격 자동 검사 | ✅ 통과 | [GCP validation](https://github.com/SoftBankHackathon2026/oneaction-infra/actions/runs/42042580051), 커밋 1926fe2 |
| 코드 원격 반영 | ✅ 기존 초안 #3에 반영 | 사용자의 명시적 승인 후 GitHub 명령줄 도구로 제목·본문 수정 및 조회 검증 완료. 초안·미병합 상태 유지. 실제 배포는 아래 기록과 구분하여 진행 |
| 실제 생성 계획·배포 | ✅ 코어 적용 / ❌ 전체 대응 미완료 | 코어 적용 성공·최종 재계획 차이 0. GKE/SQL/Kafka/저장소/Ingress 기능 시험 통과; 외부 입력과 전체 동등성 검증 남음 |
| Slack 공유 | ❌ 미게시·추가 인증 중단 | 사용자가 추가 본인 확인 절차가 필요 없다고 지시하여 중단. 현재 전체 범위/배포 보고는 미전송 |

최신 관찰값과 검증 결과는 [근거 요약 JSON](evidence/ghost-project-deployment-2026-11-06.json)에 저장했습니다. 새 대상 설정과 현재 상태는 [ghost-project 배포 기록](ghost-project-deployment-2026-11-05.md), 이전 보완 검증은 [기존 배포 준비 기록](gcp-deployment-2026-11-05.md)을 참고합니다. 문서 작성·모의 시험 통과를 배포 완료로 집계하지 않습니다.

## 공유 상태

- 상세 체크리스트는 이 프로젝트 로컬 문서에 저장했습니다. GitHub와 Notion에는 아직 게시하지 않았습니다.
- 앞선 Kubernetes 우선 계획은 Slack에 게시되어 있으나, 이번 전체 범위 정정 보고는 아직 게시하지 못했습니다. 앞선 시도에서는 앱 입력·브라우저 로딩이 진행되지 않았고, 재시도에서는 Google 패스키 본인 확인을 요구했습니다. 사용자 지시에 따라 추가 인증 절차를 중단했으며, 이번 보고는 전송하지 않았습니다.
- ❌ Slack 전체 범위 정정 보고는 미게시입니다. 추가 인증을 요구하는 경로는 사용자 지시로 중단했습니다.
- Slack에 보고할 핵심: AWS Terraform 58개 파일·94개 선언·11개 구성 전체를 기준으로 GCP를 대응합니다. AWS 실제 상태는 11/11 미확인입니다. GCP 코어는 생성·연결 시험을 마쳤고 전체 11개 구성 완료 기준의 검증은 남아 있습니다. 기존 GCP 초안의 Tailscale·논리 디코딩·방화벽 로그·알람·인증서 차이를 보완하며, 인프라 28~44인시·앱 전체 포함 시 예비 48~80인시로 추정합니다. 기존 Kubernetes 전용 범위 분리 계획을 대체합니다.

용어: Terraform은 인프라 구성 자동화 도구, IaC는 인프라를 코드로 관리하는 방식입니다. GKE/EKS는 Google/AWS 관리형 Kubernetes, DB는 데이터베이스, NAT는 사설망 외부 통신, DNS는 도메인 이름 해석, IAM은 계정·권한 관리입니다. ESO는 외부 비밀정보 동기화 도구, CSI는 컨테이너 저장소 연결 규격, StorageClass는 볼륨 생성 정책, NEG는 부하분산 대상 엔드포인트 그룹, GitOps는 Git에 저장한 설정을 기준으로 배포하는 방식입니다. TLS/HTTPS는 통신 암호화, SASL/OAuth는 인증 방식, 인시는 1명이 실제 작업하는 시간입니다.


## 대상 프로젝트 변경 이후 근거

- 현재 대상의 [조회 근거](evidence/ghost-project-deployment-2026-11-05.json)를 별도로 기록합니다. 이전 softbank-ghost 근거 파일은 과거 관찰로 보존합니다.
- 배포 상태 버킷 후보는 `ghost-project-513812-tfstate`, 플랫폼 상태 경로는 `gcp/dev/platform`입니다. 전용 상태 버킷을 생성하고 재계획 차이 0 및 원격 상태 연결을 확인했습니다.
- 사용자 승인 후 실행 인증·실제 자원 조회·필수 API 활성화·실제 계획 검토와 적용을 진행했습니다. 최신 근거는 [2026-11-06 진행 기록](evidence/ghost-project-deployment-2026-11-06.json)입니다.

## 2026-11-06 실제 배포 결과

| 항목 | 상태 | 실제 근거와 남은 일 |
|---|---|---|
| 상태 저장소·코어 계획 | ✅ 적용·재계획 차이 0 | 상태 버킷 별도, 플랫폼 상태 자원 62개(API·권한·경로 객체 포함). AWS 94개 선언과 개수 비교 불가 |
| 네트워크·저장소 | ✅ 생성·기본 통신 | VPC·서브넷·NAT·사설 연결·버킷/6경로. 사설 노드 다운로드·워크로드 읽기 성공 |
| GKE | ✅ 3노드 Ready | 서울 3영역, e2-custom-2-4096, 디스크20GiB, 버전1.36.4-gke.2046003. 실제 임시 영구 볼륨 쓰기/읽기 성공 |
| PostgreSQL | ✅ RUNNABLE·사설 암호화 접속 | 16, db-custom-1-3840, 10.20.128.3, 논리 디코딩·백업 활성. 워크로드 계정과 프록시로 SELECT 1 성공. 복구 시험 남음 |
| Kafka | ✅ ACTIVE·인증·생산/소비 | 4vCPU/4GiB·브로커3대, 실제 발급 주소 사용. 임시 토픽 복제3/min.insync2 검증 후 삭제. 업무 토픽 미구성 |
| Ingress | ✅ 외부 HTTP 200 | 예약34.149.47.248·정상 백엔드. 임시 응답기는 정리했으며 업무 앱은 미배포. 도메인/HTTPS 남음 |
| 비밀정보 동기화 | ✅ 운영자2개·DB Ready / ❌ 앱/알림 | DB 비밀1개 동기화. 나머지2개는 비밀값 미제공으로 Ready=False이며 임의 값으로 채우지 않음 |
| 로그·경보 | ✅ sink/작성자·정책4개 / ❌ 수신 검증 | LB 경보는 Monitoring의 l7_lb_rule로 수정. 이메일 채널과 수신 시험 남음 |
| 관리자 권한 | ✅ 승인 범위 반영 | 해당 프로젝트 배포 사용자에 ContainerAdmin, Terraform admin_members에도 등록. 공개 관리 주소0.0.0.0/0은 사용자 명시 지시 |
| 임시 시험 자원 | ✅ 정리 | 볼륨/Pod·SQL Job·클라우드/Kafka Job·웹 응답기·클라이언트·임시 토픽 삭제. 실제 인프라는 유지 |
| 전체 범위 잔여 | ❌ 입력/검증 대기 | 도메인/인증서·수신 이메일·Tailscale·앱/배포 비밀값·예산/종료일·AWS 실조회·복구/경계/지속성 검증 |

최초 사설 연결 권한·Kafka 서브넷 경로·로그 권한·LB 지표 이름 오류는 기록을 보존하고 수정했습니다. Kafka 접속 주소는 구형 명명 규칙으로 추측하지 않고 실제 API 조회값을 입력해 출력합니다. Terraform 모의 시험 20개 통과, 최종 재계획은 변경 0건입니다. 이는 현재 코어 입력에 대한 결과이며 `require_full_scope=false`, `enable_tailscale=false`입니다. 전체 범위 검사를 완료한 것으로 보고하지 않습니다.

근거: [최종 자원 조회](evidence/ghost-project-final-resources-2026-11-06.json), [최종 자원 목록 16종](evidence/ghost-project-preflight-final-2026-11-06.json), [DB 시험](evidence/ghost-project-sql-smoke-2026-11-06.json), [디스크 시험](evidence/ghost-project-storage-smoke-2026-11-06.json), [저장소·Kafka·외부 웹 시험과 정리](evidence/ghost-project-cloud-smoke-2026-11-06.json), [재계획 차이 0](evidence/ghost-project-final-recheck-2026-11-06.txt).
