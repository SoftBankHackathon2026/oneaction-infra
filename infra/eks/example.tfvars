# Copy to local.auto.tfvars (ignored by Git) and replace both examples.
public_access_cidrs = ["203.0.113.10/32"]
admin_principal_arns = [
  # IAM Identity Center 역할은 경로까지 전체 ARN 으로 넣는다 (aws iam list-roles --path-prefix /aws-reserved/)
  "arn:aws:iam::974402993422:role/aws-reserved/sso.amazonaws.com/ap-northeast-2/AWSReservedSSO_AdministratorAccess_ab7a6fa536de4baa",
]

# Retain the same Owner convention as existing stacks, or set the agreed owner.
owner = "hyeyeon.kim"

cluster_version     = "1.36"
node_instance_types = ["t3.medium"]
node_scaling = {
  min     = 3
  desired = 3
  max     = 3
}
