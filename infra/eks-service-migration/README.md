# service-migration 접수서비스 인증값 공급 (ESO · Pod Identity)

상태 키 `dev/eks-service-migration/terraform.tfstate`. `infra/eks-sample-app` 와 같은 방식이다.

만드는 것: Secrets Manager `oneaction/service-migration`(값 없음), IAM 역할
`ghost-oneaction-external-secrets-service-migration`(GhostWorkloadBoundary, 이 비밀과
`oneaction/sample-app` 두 개만 읽기), `external-secrets/external-secrets-service-migration`
ServiceAccount 에 대한 Pod Identity 연결.

소비하는 쪽: gitops `argocd/aws-migration/external-secrets-service-migration.yaml`(전용 ESO
인스턴스) 과 `apps/service-migration-aws/external-secrets.yaml`(SecretStore·ExternalSecret →
Secret `service-migration-auth` 의 `api-token`·`control-token`·`app-token`).

```sh
terraform init -backend-config=../backend.hcl
terraform validate
terraform plan -out=service-migration.tfplan   # 생성 4개, 변경·삭제 0 이어야 한다
terraform apply service-migration.tfplan
```

비밀 값은 Terraform 에 넣지 않는다. 적용 뒤 JSON `{"api_token":"…","control_token":"…"}` 을
`aws secretsmanager put-secret-value` 로 넣는다. 온프렘 `hackathon` 의 Secret
`service-migration-auth` 는 같은 두 값을 `kubectl create secret` 으로 만든다(기존
`durable-ingress-control` 과 같은 관례). 값은 명령 기록·tfvars·Git 에 남기지 않는다.

되돌리기: gitops 쪽 ESO 리소스를 먼저 지운 뒤 이 root 를 destroy 한다. 비밀은
`prevent_destroy` 라 30일 복구 기간을 두고 콘솔/CLI 로 따로 예약 삭제한다.
