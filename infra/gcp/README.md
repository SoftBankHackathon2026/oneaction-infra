# oneaction GCP 대응 인프라

> 작업 계획: [[docs/gsd-worklog/M001/S001/T001/T001-PLAN|Terraform 구현]] · [[docs/gsd-worklog/M001/S001/T002/T002-PLAN|배포 연결·문서]]

- 기존 `infra/network`, `eks`, `database` 등 AWS 코드는 그대로 사용합니다.
- GCP는 `infra/gcp`라는 별도 Terraform 진입점과 Cloud Storage 상태를 사용합니다. AWS 상태를 옮기거나 기존 리소스를 GCP로 바꾸지 않습니다.
- 클라우드 리소스는 공급자(provider)가 달라 분리했습니다. 구성 단위·문서 버킷 경로·데이터베이스 이름·Kubernetes 시크릿 키는 기존 구성을 유지합니다.
- 기존 `infra/eks-eso/helm-values*.yaml`과 권한 보정 도구 `post_renderer.py`는 재사용합니다. 생성기가 AWS 환경변수를 제거하고 GCP Workload Identity 연결만 추가합니다.
- 실제 클라우드 생성·데이터 이전·애플리케이션 배포는 수행하지 않았습니다. 모의 공급자 시험은 API 호출 없이 계획의 스키마와 설정값을 검사합니다.

## AWS와의 대응

| AWS 구성 | GCP 구성 | 유지한 동작과 차이 |
| --- | --- | --- |
| `network` | `network/` | 전용 가상망, 사설 노드·데이터 계층, NAT, 내부 Google API 접근, 네트워크 흐름 로그. GCP 서브넷은 영역별이 아닌 리전 단위입니다. |
| `storage` | `storage/` | 검토 문서·로그 버킷, 버전 관리, 공개 차단, 기본 저장 암호화, 로그 30일 보관. 객체 저장 API는 S3와 다릅니다. |
| `dns` | `dns/` | 선택적 Cloud DNS 영역·A/CAA 레코드·조회 로그. 새 영역은 등록기관에서 네임서버 위임이 필요합니다. |
| `database` | `database/` | PostgreSQL 16, 20–100 GiB, 사설 주소, 암호화 연결, 1일 백업. 기본 단일 영역이며 고가용성은 선택입니다. |
| `alb` | `load-balancer/` + 생성 Ingress | 고정 공개 주소·선택적 관리 인증서는 Terraform, 트래픽 전달 리소스는 GKE 내장 Ingress가 소유합니다. 같은 리소스를 두 도구가 관리하지 않습니다. |
| `observability` | `observability/` | Cloud Logging·Storage 로그 수집, SQL CPU/디스크·NAT 오류·로드밸런서 5xx 알람, 선택적 이메일. |
| `eks` | `gke/` | 사설 작업 노드·접근 주소 제한·노드 전용 계정·Workload Identity. 기본 리전형 GKE의 3개 영역에 `e2-medium` 1대씩, 총 3대입니다. 자동 증설은 설치하지 않습니다. |
| `eks-lbc` | GKE 내장 Ingress | 별도 AWS 컨트롤러를 설치하지 않습니다. 생성 Service의 NEG(네트워크 엔드포인트 그룹)와 BackendConfig가 Pod 주소로 전달합니다. |
| `eks-eso` | `secrets/` + 기존 Helm 설정 | 목적별 계정, 비밀정보별 읽기 권한, 기존 `review-db-credentials`의 `username`·`password` 키와 서비스 비밀정보 키 유지. |
| `msk` | `kafka/` | 사설 관리형 Kafka. 기본 3 가상 CPU·3 GiB 메모리이며 브로커 수는 서비스가 결정합니다. 암호화·인증이 필수입니다. |

## 경로와 상태

- `main.tf`: 필요한 Google API 활성화와 구성 단위 연결.
- `variables.tf`: 프로젝트·리전·환경·접근 주소·노드·데이터베이스·DNS·Kafka 설정.
- `outputs.tf`: 비밀값이 없는 `platform` 연결 정보.
- `bootstrap/`: 버전 관리·공개 차단·삭제 보호를 갖춘 상태 저장 버킷. 처음에는 로컬 상태를 사용합니다.
- `tests/`: 기본 구성, 다른 리전/환경, 도메인, Kafka 제외, 오류 입력, 권한·개별 리소스 계획 시험.
- GCP 플랫폼은 환경당 상태 1개에서 하위 구성을 연결합니다. 기존 AWS의 구성별 원격 상태를 그대로 복제하면 예시 계정·상태 주소까지 공유하게 되므로 이 구성을 택했습니다.
- GKE는 같은 프로젝트의 클러스터끼리 Workload Identity 풀과 동일한 namespace/서비스 계정 주체를 공유합니다. 이 구성은 기존 계정 이름을 유지하므로 **개발/운영 간 강한 권한 격리가 필요하면 프로젝트를 분리**합니다. 환경 이름과 상태 prefix만으로 권한이 격리되지는 않습니다.
- 환경을 새로 만들 때는 작업 폴더와 상태 `prefix`도 분리합니다. 같은 상태에서 `environment`만 바꾸면 기존 리소스의 이름 변경·교체 계획이 생깁니다. AWS 상태를 GCP에 전달하지 않습니다.
- 가상망 주소는 기존 AWS `10.0.0.0/16`과 겹치지 않게 노드 `10.20.32.0/19`, 데이터 `10.20.10.0/24`, Cloud SQL 예약 `10.20.128.0/20`, Pod `10.24.0.0/14`, Service `10.28.0.0/20`, 제어 영역 `172.20.0.0/28`을 사용합니다. 기존 조직망과의 중복은 적용 전 확인합니다.

## 사전 준비

- Terraform 1.11 이상 2 미만(검증 버전 1.13.5), Google 공급자 7.29.x(잠금 파일 7.29.0), Python 3.9 이상.
- `gcloud`, `kubectl`, Helm 3. 기존 권한 보정 도구는 Helm 3의 post-renderer 옵션을 사용합니다.
- 요금 결제가 연결된 실제 GCP 프로젝트, 서비스 활성화와 해당 리소스·권한·상태 버킷을 관리할 배포자 권한. 상태 저장 버킷 접근은 배포자에게만 별도로 부여하고 워크로드에는 주지 않습니다.
- 배포자는 노드 계정을 지정할 `iam.serviceAccounts.actAs` 권한도 필요합니다. `admin_members`는 클러스터 관리자용이며 Terraform 실행자 권한을 대신하지 않습니다.
- `gcloud auth application-default login`으로 로컬 Terraform용 인증을 준비합니다. `gcloud` 명령용 로그인도 별도 확인합니다. 서비스 계정 키 파일은 만들지 않습니다.
- 리전별 영역·GKE 버전·SQL/Kafka 지원·할당량은 실제 프로젝트에서 확인합니다. AWS Kubernetes `1.36`을 강제 복사하지 않고 GKE `REGULAR` 출시 채널의 지원 버전을 사용합니다.

## 적용 순서

아래 명령은 운영자가 실제 생성할 때 실행하는 절차입니다. 이 변경에서 실행한 명령은 검증 절의 명령뿐입니다.

1. 상태 저장 버킷을 별도 구성으로 준비합니다. 아래 예시의 프로젝트와 버킷 이름은 실제 값으로 바꿉니다.

   ```bash
   terraform -chdir=infra/gcp/bootstrap init
   terraform -chdir=infra/gcp/bootstrap plan \
     -var='project_id=your-project-id' -var='bucket_name=your-unique-state-bucket' -out=bootstrap.tfplan
   terraform -chdir=infra/gcp/bootstrap apply bootstrap.tfplan
   ```

   버킷은 기본 GCS(Cloud Storage) 저장 암호화·버전 관리·상태 잠금을 사용합니다. DynamoDB는 사용하지 않습니다. `bootstrap`의 로컬 상태도 보관하고 접근을 제한합니다. 이를 원격 보관하려면 별도 관리 경로로 이전하며 플랫폼 상태와 합치지 않습니다.

2. 플랫폼 상태 설정과 입력값을 만듭니다.

   ```bash
   cp infra/gcp/backend.hcl.example infra/gcp/backend.local.hcl
   cp infra/gcp/example.tfvars infra/gcp/environment.local.tfvars
   # backend.local.hcl: 실제 bucket, 환경별 prefix(gcp/dev/platform)
   # environment.local.tfvars: project_id, 실제 관리자 출구 주소, 필요 시 도메인/알림
   terraform -chdir=infra/gcp init -backend-config=backend.local.hcl
   ```

3. 비밀번호를 셸 환경변수로만 전달하고 계획을 검토한 뒤 적용합니다. 다음 입력 예시는 Bash 기준입니다.

   ```bash
   read -r -s -p 'Cloud SQL password: ' TF_VAR_db_password
   export TF_VAR_db_password
   terraform -chdir=infra/gcp plan -var-file=environment.local.tfvars -out=gcp.tfplan
   terraform -chdir=infra/gcp apply gcp.tfplan
   terraform -chdir=infra/gcp output -json platform > infra/gcp/platform.local.json
   ```

   `db_password`는 임시 변수(ephemeral variable)이며 `google_sql_user.password_wo`(쓰기 전용 인자)에만 전달됩니다. 비밀번호는 상태·계획 파일에 보관하지 않습니다. 저장 계획을 적용할 때도 같은 환경변수가 필요합니다. 회전 시 `db_password_version`을 올리고 Secret Manager 값도 함께 갱신합니다. 계획 파일은 비밀번호 외 인프라 정보가 있으므로 별도로 보호합니다.

4. 생성한 Secret Manager 비밀정보에 값을 등록합니다. Terraform은 비밀정보의 메타데이터·권한만 관리합니다. 데이터베이스에는 앞서 사용한 비밀번호를 그대로 등록합니다.

   ```bash
   python3 - <<'PYCODE'
   import json, os, subprocess
   from pathlib import Path
   p = json.loads(Path('infra/gcp/platform.local.json').read_text())
   payload = json.dumps({'username': p['database']['username'], 'password': os.environ['TF_VAR_db_password']})
   subprocess.run(['gcloud', 'secrets', 'versions', 'add', p['secrets']['database'],
                   '--project', p['project_id'], '--data-file=-'], input=payload, text=True, check=True)
   PYCODE
   unset TF_VAR_db_password
   ```

   - `gitops` 비밀정보: 기존 AWS와 같은 **평문 토큰**. 보호한 파일을 `gcloud secrets versions add <secret-id> --project <project-id> --data-file=<protected-file>`로 등록합니다.
   - `review_service` 비밀정보: `ANTHROPIC_API_KEY`, `GITHUB_WEBHOOK_SECRET`, `ARGOCD_WEBHOOK_TOKEN`, `REVIEW_API_TOKEN` 4개 키를 가진 JSON. 같은 방식으로 파일에서 등록하며 값을 코드·명령행·출력에 넣지 않습니다.
   - 등록되지 않은 키가 있으면 External Secrets Operator가 동기화하지 못합니다. 실제 값의 등록과 권한 전파를 확인한 뒤 앱을 연결합니다.

5. 대상 클러스터 접근 정보를 받고 설정을 생성합니다.

   ```bash
   gcloud container clusters get-credentials oneaction-dev --region asia-northeast3 --project your-project-id
   python3 -m venv .venv
   .venv/bin/pip install -r requirements-dev.txt
   .venv/bin/python scripts/install-gcp-platform.py \
     --platform infra/gcp/platform.local.json \
     --context gke_your-project-id_asia-northeast3_oneaction-dev \
     --output-dir infra/gcp/rendered
   ```

   기본 실행은 파일 생성과 실행할 명령 표시만 합니다. 프로젝트·위치·클러스터 이름이 맞지 않는 context는 거절합니다. 실제 적용은 출력 검토 후 같은 명령에 `--apply`를 추가합니다. 이 도구는 네임스페이스, 기존 Helm 설정을 재사용한 시크릿 동기화 도구 2개, 비밀정보 연결과 진입점만 적용합니다. 앱 이미지나 데이터베이스 스키마는 배포하지 않습니다.

6. 기존 GitOps 배포와 연결합니다.

   - `rendered/workload-patch.yaml`은 `review-api`의 `api` 컨테이너, `worker-patch.yaml`은 `review-worker`의 `worker` 컨테이너에 적용하는 **Kustomize 병합 조각**입니다. 단독 `kubectl apply` 대상이 아닙니다.
   - 서비스 계정은 `platform/review-service`를 사용합니다. Cloud SQL Auth Proxy가 같은 Pod 안에서 `127.0.0.1:5432`를 열고 사설 주소로 암호화·인증하여 연결합니다. 앱의 `DB_SSLMODE=disable`은 Pod 안의 루프백 구간에만 적용됩니다. 프록시를 빼고 사설 DB에 이 값을 사용하면 안 됩니다.
   - 생성 Service는 기존 `platform:8080`, 선택자는 `app=review-api`입니다. 기존 AWS `TargetGroupBinding`과 AWS 접속 ConfigMap을 GCP에 그대로 적용하지 않습니다. `KAFKA_BOOTSTRAP`, `DEFAULT_TARGET`, `REVIEW_API_PUBLIC_URL`, `APP_URLS` 등의 AWS 주소도 GCP의 실제 연결값으로 조정해야 합니다.
   - 기존 GitOps에 있는 AWS `review-service-secrets` ExternalSecret 대신 생성된 GCP 설정을 사용합니다. 두 선언이 같은 Kubernetes Secret을 동시에 관리하지 않도록 기존 리소스를 선택적으로 구성합니다.
   - Argo CD와 Argo Rollouts는 기존 GitOps 설치 절차·고정 버전을 재사용할 수 있습니다. 이 저장소는 다른 저장소의 Application 목적지나 자동 동기화를 바꾸지 않습니다.
   - Argo CD Notifications의 `ARGOCD_WEBHOOK_TOKEN`은 기존 Secret에 `Merge`합니다. Argo CD 설치가 `argocd-notifications-secret`을 만든 뒤 동기화됩니다. webhook URL·알림 템플릿은 기존 GitOps에서 GCP용으로 연결해야 합니다.
   - Prometheus·Grafana·업무용 테이블·Qdrant 등 애플리케이션 계층은 기존 GitOps/초기화 절차의 범위입니다. 이 인프라 변경만으로 검토 서비스 전체가 바로 실행된다고 보장하지 않습니다.

## Kafka와 객체 저장소 연결 차이

- Managed Kafka는 AWS 코드의 `PLAINTEXT` 무인증 접속을 지원하지 않습니다. `platform.kafka`에 `SASL_SSL`, `OAUTHBEARER`, 비밀 키 없는 기본 인증 정보(ADC, Application Default Credentials) 사용을 출력합니다.
- `platform.identities.workload`에는 `roles/managedkafka.client`를 부여합니다. GKE의 연결된 서비스 계정을 쓰되 클라이언트 라이브러리에 OAuth 토큰 자동 갱신 기능을 연결해야 합니다. 기존 앱이 `KAFKA_BOOTSTRAP`만 지원하면 주소 변경만으로 작동하지 않습니다. 앱 소스 변경은 이 저장소 범위 밖입니다.
- 공급자 7.29는 실제 bootstrap 주소 속성을 노출하지 않아 출력은 문서의 기본 주소 형식으로 구성합니다. **실제 사용 전 아래 조회 결과와 일치하는지 반드시 확인**하고 다르면 실제 조회값을 클라이언트에 사용합니다.

  ```bash
  gcloud managed-kafka clusters describe oneaction-dev-review \
    --project your-project-id --location asia-northeast3 --format='value(bootstrapAddress)'
  ```

- 브로커 수·버전·복제 정책은 MSK와 같게 고정할 수 없습니다. 토픽은 작업별로 따로 생성·검증하고 데이터 이전을 별도로 수행합니다.
- `enable_kafka=false`이면 Kafka 리소스·API 활성화·클라이언트 권한을 제외합니다. 애플리케이션의 Kafka 의존성까지 자동으로 끄지는 않습니다.
- 문서 버킷의 객체 경로는 유지하지만 S3와 GCS의 호출·권한은 다릅니다. 기존 앱이 AWS SDK에 고정되어 있으면 GCS 클라이언트/저장소 추상화가 필요합니다. 이 변경은 평문 상호운용 키를 생성하지 않습니다.

## 도메인·로그·알람

- `domain_name`이 비어 있으면 DNS·인증서 없이 HTTP 진입점을 구성합니다. 공개 인증 정보를 HTTP로 전달하지 않으며 공개 운영 전에 소유 도메인과 인증서를 준비합니다.
- `domain_name`이 있으면 관리 인증서·HTTPS 전환 설정을 생성합니다. 새 Cloud DNS 영역은 `dns_domain` 또는 앱 도메인으로 생성하고 `platform.dns_name_servers`로 네임서버를 확인합니다. 기존 영역이면 `dns_zone_name`을 지정합니다.
- 기존 도메인을 변경할 때는 인증서가 고정 이름이므로 자동 교체하지 않습니다. 운영자가 먼저 Ingress의 이전 인증서 참조를 해제하고 GKE 프록시에서 제거된 것을 확인한 뒤 Terraform 변경을 적용하고 새 인증서를 다시 연결합니다. 이 구간은 HTTPS 중단이 있으므로 운영 중에는 별도 이름의 인증서를 준비하는 교체 작업으로 분리합니다. Ingress를 제거하지 않고 인증서를 먼저 삭제하면 사용 중 오류가 날 수 있습니다.
- 인증서가 실제 발급되려면 공개 DNS가 예약 주소를 가리키고 GKE Ingress가 정상 연결되어야 합니다. 생성 계획 통과는 발급 완료를 뜻하지 않습니다.
- BackendConfig가 로드밸런서 요청 로그를 수집합니다. 오류 알람은 GKE가 생성하는 URL-map 이름에 포함된 `platform/<환경 이름>-platform`을 기준으로 범위를 제한합니다. 실제 적용 후 Cloud Logging에서 이름·로그·시험 오류를 확인합니다.
- `notification_email`이 없으면 알람 정책만 만들고 이메일 채널은 만들지 않습니다. 수신 여부는 실제 프로젝트에서 확인합니다.
- Cloud Logging의 프로젝트 전체 기본 보존 설정은 변경하지 않습니다. 선택한 GKE·SQL·NAT·로드밸런서·서브넷 로그를 로그 버킷에 내보내며 버킷은 30일 수명 주기를 갖습니다.

## 검증

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m unittest discover -s tests -v
terraform fmt -check -recursive infra/gcp
terraform -chdir=infra/gcp init -backend=false -input=false
terraform -chdir=infra/gcp validate
terraform -chdir=infra/gcp test
terraform -chdir=infra/gcp/bootstrap init -backend=false -input=false
terraform -chdir=infra/gcp/bootstrap validate
```

- 실제 Google 자격증명 없이 mock provider(모의 공급자)로 실행합니다. 원격 상태 초기화나 실제 API 계획은 실행하지 않습니다.
- 모의 계획은 공급자 스키마·입력 검증·구성 계약을 확인합니다. 할당량, 실제 권한, 인증서 발급, 시크릿 값, Kafka 통신, 프록시 연결, Ingress 상태는 클라우드 적용 후 별도 확인해야 합니다.
- 저장소의 `GCP validation` 자동 검사도 같은 범위만 실행합니다. Terraform apply나 클러스터 적용은 자동화하지 않습니다.

## 설계 근거

- [GKE 기본 노드 계정의 최소 역할](https://docs.cloud.google.com/kubernetes-engine/security/configure-node-service-accounts)
- [GKE에서 Cloud SQL 연결과 Auth Proxy](https://docs.cloud.google.com/sql/docs/postgres/connect-kubernetes-engine)
- [쓰기 전용 Cloud SQL 비밀번호 인자](https://registry.terraform.io/providers/hashicorp/google/7.29.0/docs/resources/sql_user)
- [External Secrets Operator의 Google Secret Manager 인증](https://external-secrets.io/v2.12.0/provider/google-secrets-manager/)
- [관리형 Kafka 지원 리전](https://docs.cloud.google.com/managed-service-for-apache-kafka/docs/locations)
- [Kafka 클러스터 용량과 네트워크](https://docs.cloud.google.com/managed-service-for-apache-kafka/docs/create-cluster)
- [Kafka 인증과 클라이언트 역할](https://docs.cloud.google.com/managed-service-for-apache-kafka/docs/authentication-kafka)
- [실제 Kafka bootstrap 주소 조회](https://docs.cloud.google.com/managed-service-for-apache-kafka/docs/view-cluster)
