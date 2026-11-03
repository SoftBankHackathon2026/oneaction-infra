# Secrets Manager 그릇

`eks-eso`가 읽는 두 Secret을 만듭니다. Terraform은 Secret 이름·설명만 관리하고 값은 다루지 않습니다.
`aws_secretsmanager_secret_version`을 쓰면 값이 상태 파일에 평문으로 남기 때문입니다.

| Secret | 형식 | 읽는 곳 |
| --- | --- | --- |
| `oneaction/review-service` | JSON: `ANTHROPIC_API_KEY`, `GITHUB_WEBHOOK_SECRET`, `ARGOCD_WEBHOOK_TOKEN`, `REVIEW_API_TOKEN` | gitops `apps/review-service/externalsecret.yaml`, Argo CD Notifications |
| `oneaction/gitops-token` | 평문 GitHub 토큰 | gitops `apps/review-service/externalsecret.yaml`의 `GITHUB_TOKEN` |

## 적용과 값 넣기

```bash
cd infra/secrets
terraform init -backend-config=../backend.hcl
terraform plan -out=tfplan && terraform apply tfplan

# 값은 파일에서 읽어 넣고, 셸 기록·채팅에 남기지 않는다
aws secretsmanager put-secret-value --secret-id oneaction/review-service \
  --secret-string file://review-service.json
aws secretsmanager put-secret-value --secret-id oneaction/gitops-token \
  --secret-string file://gitops-token.txt
rm -P review-service.json gitops-token.txt
```

`eks-eso`를 plan하기 전에 두 Secret 모두 값이 한 번 이상 들어가 있어야 ESO 동기화가 성공합니다.
ARN은 `terraform output -raw review_service_secret_arn`, `terraform output -raw gitops_token_secret_arn`으로 얻어
`eks-eso`에 넘깁니다.
