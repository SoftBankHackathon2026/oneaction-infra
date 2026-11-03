provider "aws" {
  profile             = var.aws_profile == "" ? null : var.aws_profile
  region              = var.aws_region
  allowed_account_ids = ["974402993422"]

  default_tags {
    tags = {
      Project = "oneaction"
      Owner   = var.owner
      Env     = "dev"
    }
  }
}

# Secrets Manager 그릇만 만든다. 값(aws_secretsmanager_secret_version)은 Terraform 상태에 평문으로
# 남으므로 여기서 다루지 않고, README 의 put-secret-value 절차로 넣는다.
# eks-eso 스택이 이 ARN 들을 읽어 ESO 읽기 권한을 Secret 하나 단위로 준다.

resource "aws_secretsmanager_secret" "review_service" {
  name                    = "oneaction/review-service"
  description             = "review-service JSON: ANTHROPIC_API_KEY, GITHUB_WEBHOOK_SECRET, ARGOCD_WEBHOOK_TOKEN, REVIEW_API_TOKEN"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret" "gitops_token" {
  name                    = "oneaction/gitops-token"
  description             = "Plaintext GitHub token the review worker uses to commit to the gitops repository"
  recovery_window_in_days = 7
}
