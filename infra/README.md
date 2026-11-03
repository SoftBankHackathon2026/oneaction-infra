# oneaction AWS 기반 인프라

공통 AWS 리소스와 EKS 구성을 상태 키별 Terraform 스택으로 관리합니다.

## 전제

- AWS 계정: `974402993422` (t3underline). 모든 스택의 provider가 `allowed_account_ids`로 이 계정 밖의 실행을 거부합니다.
- AWS Region: `ap-northeast-2`
- 상태: S3 `oneaction-tfstate-974402993422`, 잠금 DynamoDB `oneaction-terraform-locks` (둘 다 계정에 미리 있음)
- Terraform 1.5.7 이상 2.0 미만
- 공통 태그: `Project=oneaction`, `Owner=hyeyeon.kim`, `Env=dev`

## 인증과 실행

각 팀원은 `aws login`으로 로그인합니다. 이 저장소가 고정한 AWS provider 5.x는 `aws login` 세션을 직접 읽지
못합니다(provider 6.x, Terraform 1.15 이상의 S3 backend는 읽음). 그래서 Terraform 전용 프로필을 하나 두고
`credential_process`로 연결합니다. SDK가 만료 시점마다 자격증명을 다시 받아 오므로 긴 apply 중에도 끊기지 않습니다.

`~/.aws/config`에 한 번만 추가합니다. `aws login`이 쓰는 프로필(`<profile>`)에는 `credential_process`를 넣지 않습니다.

```ini
[profile <profile>-tf]
region = ap-northeast-2
credential_process = aws configure export-credentials --profile <profile> --format process
```

```bash
aws login --profile <profile>          # 리전은 ap-northeast-2
export AWS_PROFILE=<profile>-tf AWS_REGION=ap-northeast-2
aws sts get-caller-identity --query Account --output text   # 974402993422 여야 한다
```

`eval "$(aws configure export-credentials ... --format env)"`로 환경변수에 넣는 방식은 쓰지 않습니다. 그 값은 약 15분 뒤
만료되고 갱신되지 않아서, 20~30분 걸리는 EKS·MSK 적용이 중간에 실패할 수 있습니다.
IAM Identity Center 시작 URL을 쓰는 `aws configure sso` 프로필도 provider 5.x가 직접 읽으므로 그 방식을 써도 됩니다.

각 스택에서 다음 순서로 실행합니다.

```bash
terraform init -backend-config=../backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

## 적용 순서 (빈 계정 기준)

뒤 스택은 앞 스택의 원격 상태를 읽으므로 순서를 바꾸지 않습니다.

| 순서 | 스택 | 필요한 입력 |
| --- | --- | --- |
| 1 | `network` | 없음 |
| 2 | `storage` | 없음 |
| 3 | `secrets` | 적용 후 두 Secret에 값을 넣는다. [secrets/README.md](secrets/README.md) |
| 4 | `dns` | `domain_name`. 적용 후 상위 존에 NS 위임 (아래 참고) |
| 5 | `database` | 없음 |
| 6 | `alb` | HTTPS를 쓰면 `certificate_arn`, `hosted_zone_id`, `domain_name`, `app_subdomain` (dns 출력) |
| 7 | `observability` | 선택: `notification_email` |
| 8 | `eks` | `public_access_cidrs`, `admin_principal_arns` ([eks/example.tfvars](eks/example.tfvars)를 `local.auto.tfvars`로 복사) |
| 9 | `eks-ebs-csi` | 적용 후 StorageClass manifest 적용. [eks-ebs-csi/README.md](eks-ebs-csi/README.md) |
| 10 | `eks-lbc` | 적용 후 Helm 설치. [eks-lbc/README.md](eks-lbc/README.md) |
| 11 | `eks-eso` | `gitops_token_secret_arn`, `review_service_secret_arn` (secrets 출력). 적용 후 Helm 설치 |
| 12 | `msk` | 없음. 출력 `bootstrap_brokers`를 검토 서비스 `KAFKA_BOOTSTRAP`에 넣는다 |

`msk`는 `network`만 필요하므로 1번 뒤 아무 때나 적용해도 됩니다. 생성에 20~30분 걸립니다.

Terraform 밖에서 남는 설치 작업은 다음과 같습니다. 각 README와 gitops 레포의 절차를 따릅니다.

- Argo CD·Argo Rollouts 설치: gitops `argocd/install/README.md`
- AWS Load Balancer Controller Helm: `eks-lbc/scripts/Install-Controller.ps1`
- External Secrets Operator Helm·SecretStore: `eks-eso/scripts/Install-Eso.ps1`
- 모니터링 StorageClass: `kubectl apply -f eks-ebs-csi/manifests/storageclass-monitoring-gp3.yaml`

## 도메인 위임

`dns` 스택은 `domain_name`의 공개 호스티드 존을 이 계정에 새로 만듭니다. 새 존의 NS 4개를 상위 존에 위임해야
ACM 인증서 검증이 끝납니다.

```bash
terraform -chdir=infra/dns output hosted_zone_name_servers
```

`app.yubin.dev`를 쓰는 경우 상위 존 `yubin.dev`(다른 계정)에 이미 `app` NS 레코드가 있습니다. 이 레코드는 지금
없어진 존을 가리켜 응답이 REFUSED입니다. 새 NS 4개로 값을 바꿉니다. 이때 `alb`의 `app_subdomain`을 `""`로 주면
`app.yubin.dev` 자체가 ALB를 가리키고, 기본값 `app`이면 `app.app.yubin.dev`가 됩니다.

## 검증 스크립트

`eks`, `eks-lbc`, `eks-eso`의 `scripts/check_*.py`, `Test-*.ps1`은 이미 적용된 환경에 변경을 더하는 단계를 기준으로
작성됐습니다. 예를 들어 "기존 리소스는 no-op" 같은 조건이 있어서 빈 계정의 첫 적용 plan에는 그대로 맞지 않습니다.
첫 적용 뒤의 steady-state 검사와 이후 변경 검사에 사용합니다.

## 미완료 외부 입력

- 실제 Route 53 도메인과 상위 존 위임
- SNS 구독 이메일
- `oneaction/review-service`, `oneaction/gitops-token` Secret 값

도메인 없이 적용하면 ALB는 HTTP 80 임시 모드입니다. 실제 도메인과 ACM 인증서가 준비되면 `alb` 스택의
`certificate_arn`, `hosted_zone_id`, `domain_name`을 전달해 HTTPS로 전환합니다.
