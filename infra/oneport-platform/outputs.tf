output "public_ip" {
  value = aws_eip.server.public_ip
}

output "eks_public_access_cidrs" {
  description = "eks 스택이 public_access_cidrs 에 더하는 플랫폼 서버 주소."
  value       = ["${aws_eip.server.public_ip}/32"]
}

output "instance_id" {
  value = aws_instance.server.id
}

output "server_role_arn" {
  value = aws_iam_role.server.arn
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}
