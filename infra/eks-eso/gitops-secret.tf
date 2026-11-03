variable "gitops_token_secret_arn" {
  description = "Full ARN of oneaction/gitops-token from the secrets stack output. Pass null explicitly to disable its read permission."
  type        = string
  validation {
    condition = var.gitops_token_secret_arn == null ? true : can(regex(
      "^arn:aws:secretsmanager:ap-northeast-2:974402993422:secret:[A-Za-z0-9/_+=.@-]+-[A-Za-z0-9]{6}$",
      var.gitops_token_secret_arn
    ))
    error_message = "Use one full Secret ARN in team account 974402993422 and Seoul, without wildcards."
  }
}

# Metadata only. The token is created and stored by its owner, outside Terraform.
data "aws_secretsmanager_secret" "gitops" {
  count = var.gitops_token_secret_arn == null ? 0 : 1
  arn   = var.gitops_token_secret_arn
}

resource "aws_iam_role_policy" "read_gitops" {
  count = var.gitops_token_secret_arn == null ? 0 : 1
  name  = "read-gitops-token-secret"
  role  = aws_iam_role.eso.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource  = var.gitops_token_secret_arn
      Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } }
    }]
  })
  lifecycle {
    precondition {
      condition     = data.aws_secretsmanager_secret.gitops[0].arn == var.gitops_token_secret_arn && var.gitops_token_secret_arn != local.secret_arn
      error_message = "Use the exact existing GitOps token Secret, separate from the RDS Secret."
    }
    precondition {
      condition     = data.aws_secretsmanager_secret.gitops[0].kms_key_id == null || data.aws_secretsmanager_secret.gitops[0].kms_key_id == ""
      error_message = "An explicit KMS key needs its key type and scoped decryption permission checked before granting access."
    }
  }
}

output "gitops_token_secret_arn" {
  value = var.gitops_token_secret_arn
}
