output "review_service_secret_arn" {
  value = aws_secretsmanager_secret.review_service.arn
}

output "gitops_token_secret_arn" {
  value = aws_secretsmanager_secret.gitops_token.arn
}
