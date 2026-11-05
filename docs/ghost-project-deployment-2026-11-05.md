# ghost-project 배포 기록

2026-11-06 한국시간 기준입니다. 사용자가 지정한 `ghost-project-513812`(프로젝트 번호251118972904, 서울 asia-northeast3)에 코어 인프라를 실제 배포했습니다. AWS Terraform 11개 구성 전체의 동등성 검증은 미완료입니다. AWS 실제 자원은 미확인이며 변경하지 않았습니다.

| 항목 | 결과 | 검증/잔여 |
|---|---|---|
| 결제·인증 | ✅ 확인 | 해커톤 결제 연결, 사용자 승인 후 공식 배포 도구 인증 |
| 원격 상태 | ✅ 적용·재계획 차이0 | ghost-project-513812-tfstate, 버전관리·공개 차단, gcp/dev/platform |
| 네트워크·저장소 | ✅ 생성·기본 통신 | 전용 VPC·GKE/data 서브넷·NAT·사설 연결·문서/로그 버킷·6개 경로. 사설 노드 다운로드·워크로드 저장소 읽기 성공 |
| GKE | ✅ 3노드 Ready | 서울3영역, e2-custom-2-4096(노드당2가상CPU/4GiB),20GiB 디스크. 버전1.36.4-gke.2046003. 실제 임시 영구 볼륨 쓰기/읽기 성공 |
| PostgreSQL | ✅ RUNNABLE·사설 암호화 접속 | 16, db-custom-1-3840, 사설IP10.20.128.3, 논리 디코딩·백업 활성. 워크로드 계정+Cloud SQL 프록시+동기화 비밀로 SELECT 1 성공. 복구 미검증 |
| Kafka | ✅ ACTIVE·인증·생산/소비 | 4가상CPU/4GiB·브로커3대 확인. 임시 토픽 복제3/min.insync2·전체 복제 확인 응답으로 메시지 송수신 성공. 시험 토픽 삭제, 업무 토픽 미구성 |
| 부하분산기 | ✅ 임시 백엔드 외부HTTP200 | 예약IP34.149.47.248·Ingress·정상 백엔드 확인. 임시 응답기는 정리했으며 업무 앱은 미배포. 도메인/HTTPS 미구성 |
| 비밀정보 동기화 | ✅ 운영자2개·DB Ready / ❌ 나머지 | External Secrets 운영자2개 설치. DB만 동기화됐으며 review-service/argocd-notifications는 값 미제공 등으로 Ready=False |
| 로그·경보 | ✅ 구성 생성 / ❌ 발송·수신 검증 | 로그 sink·버킷 작성 권한·SQL/NAT/LB 정책4개. 이메일 채널 미구성, 실제 내보내기/수신 시험 남음 |
| 관리자 | ✅ 승인 반영 | 해당 프로젝트 사용자에 ContainerAdmin 추가, Terraform admin_members에도 등록. Service Networking/로그 구성 작성자 역할도 별도 승인 후 추가 |
| 공개 관리 접속 | ✅ 사용자 지시 반영 | 테스트 환경0.0.0.0/0. allow_public_control_plane=true를 명시해야만 넓은 주소 허용, 계정 인증 필요 |
| 최종 재계획 | ✅ 변경0 | 현재 코어 입력 기준. 상태 자원62개에는 API·권한·경로 객체가 포함되어 AWS94개 선언과 직접 비교 불가 |
| 시험용 자원 | ✅ 정리 | 임시 볼륨/Pod·SQL/클라우드/Kafka Job·웹 응답기·클라이언트·토픽 삭제. 실제 인프라 유지 |
| 전체 대응 | ❌ 미완료 | 도메인/인증서·수신 이메일·Tailscale·앱/배포 비밀값·AWS 실제 조회·권한 경계/복구/지속성 시험 남음 |
| Slack 공유 | ❌ 미게시 | 사용자가 추가 본인 확인 절차를 중단하도록 지시. 완료 보고를 전송한 것으로 표시하지 않음 |

## 실제 적용과 보완

전용 상태 버킷을 만든 뒤 기반 계획28개, 코어 계획33개를 검토하여 적용했습니다. 일부 단계는 권한/서비스 오류로 부분 성공했으며, 이미 생성된 자원을 재사용해 수정했습니다. 최종 수정 계획은 관리자 역할 상태 등록과 LB 경보2개 추가, 변경0·삭제0이었고 적용 후 재계획은 변경0입니다.

- Kafka Compute 서브넷 ID는 실제 서비스가 요구하는 프로젝트 번호 경로로 정규화했습니다.
- Logging의 `http_load_balancer`와 Monitoring의 `l7_lb_rule` 이름 차이를 실제 지표 정의로 확인하여 경보를 수정했습니다.
- Kafka 접속 주소는 구형 이름 규칙으로 조합한 값이 실제 발급 주소와 달랐습니다. 제공자7.29는 해당 속성을 출력하지 않으므로 기본값은 null로 두고, `gcloud managed-kafka clusters describe ... --format='value(bootstrapAddress)'`로 조회한 주소를 `kafka_bootstrap_brokers`에 입력합니다. 잘못된 주소를 자동 생성하지 않습니다.
- 관리 권한은 사용자가 승인한 프로젝트·계정에만 추가했습니다. 관리자 목록도 실제 Terraform 입력에 반영했습니다.

현재 배포 입력은 `require_full_scope=false`, `enable_tailscale=false`인 코어 테스트 단계입니다. 예시 `ghost-project.tfvars.example`은 전체 범위 검사를 유지하며 도메인·이메일·키 참조 없이 전체 완료로 처리하지 않습니다. 데이터베이스 비밀 원문·인증 정보·상태 파일·실제 입력 파일은 Git에 넣지 않습니다.

## 검증 근거

- Terraform 모의 시험20개 통과, Python 기존 시험16개 통과. 모의 시험을 실제 클라우드 동작 검증으로 계산하지 않습니다.
- [94개 대응 체크리스트](aws-gcp-infrastructure-deployment-checklist.md): AWS 실제 상태와 GCP 생성/검증을 구분하며 ✅/❌ 표시.
- [배포 요약](evidence/ghost-project-deployment-2026-11-06.json), [최종 목록16종](evidence/ghost-project-preflight-final-2026-11-06.json).
- [영구 디스크](evidence/ghost-project-storage-smoke-2026-11-06.json), [사설 SQL](evidence/ghost-project-sql-smoke-2026-11-06.json), [저장소·Kafka·외부 HTTP와 정리](evidence/ghost-project-cloud-smoke-2026-11-06.json).
- [최종 계획 요약](evidence/ghost-project-final-plan-summary-2026-11-06.json), [재계획 변경0](evidence/ghost-project-final-recheck-2026-11-06.txt).

## 남은 입력과 후속 작업

1. 도메인/관리 경로 및 인증서 범위, 알림 이메일, Tailscale 키의 비밀 저장소 참조·테일넷/경로 승인, 앱/배포 비밀값을 준비합니다.
2. 전체 입력으로 생성 계획을 재검토한 후 DNS/HTTPS·이메일·사설 라우터를 연결합니다. 비밀값은 채팅/코드에 기록하지 않습니다.
3. 업무 토픽/앱 연결, 갱신·접근 거절·볼륨 재연결·DB 복구·로그 내보내기/알림 수신·온프렘 사설 경로 시험을 수행합니다.
4. 예산 상한·사용 종료일·철거 방침은 미확정입니다. 실제 인프라의 비용은 발생 중이며 아직 총액을 산출하지 않았습니다.

접속 예: `gcloud container clusters get-credentials oneaction-dev --region asia-northeast3 --project ghost-project-513812`. 비밀정보는 Secret Manager에서 권한에 따라 조회합니다. 실제 배포 계정은 `nate.crema@gmail.com`이며 해당 계정의 클러스터 관리자 권한을 반영했습니다.

철거는 별도 승인 후 삭제 계획·데이터/상태 보존을 검토하고 진행합니다. Ingress가 만든 부하분산기·주소·볼륨까지 확인하며 상태 버킷은 별도 보존합니다. 코드 되돌리기만으로 실제 데이터가 복구되지는 않습니다.

용어: GKE는 Google 관리형 Kubernetes, CPU는 프로세서 자원, IP는 네트워크 주소, HTTP/HTTPS는 웹 통신/암호화 웹 통신, DB/SQL은 데이터베이스/질의 언어입니다. Ingress는 외부 요청 진입 설정, Ready는 준비 완료 상태, Job/Pod는 일회성 작업/컨테이너 실행 단위입니다. API는 서비스 호출 인터페이스, IAM은 권한 관리, Terraform은 코드 기반 인프라 자동화 도구입니다.
