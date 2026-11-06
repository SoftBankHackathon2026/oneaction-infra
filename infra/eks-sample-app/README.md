# Migration application secrets

This independent state (`dev/eks-sample-app/terraform.tfstate`) owns five new
resources: `oneaction/sample-app` Secrets Manager metadata, a dedicated ESO IAM
role, a read policy restricted to that secret ARN, and its EKS Pod Identity
association, plus a new DNS alias to the existing sample ALB. Existing platform/argocd controllers and their permissions are unchanged.

The role trusts only cluster `oneaction`, namespace `external-secrets`, service
account `external-secrets-sample-app`. The GitOps repository owns the corresponding
namespace-scoped controller under `argocd/aws-migration/` and the application
ExternalSecrets under `apps/sample-app/runtime/aws/`.

Run Terraform with the team profile's temporary credentials in environment variables:

```sh
terraform init -backend-config=../backend.hcl
terraform validate
terraform plan -out=sample-app.tfplan
terraform apply sample-app.tfplan
```

Never put secret versions in Terraform. Provision JSON properties `database_url`
(the `migration_app` connection to RDS `migration_demo`) and `request_api_token`
(a random token of at least 32 characters) using an in-memory Secrets Manager API
call. Do not use the RDS admin account for the application. The onprem ingress
uses the same API token through Secret `hackathon/sample-app-eks-api-token`.
Initial Kubernetes registration was explicitly approved by the user; ordinary
workload changes continue through GitOps. Token rotation must coordinate both ends.

Validation on 2026-11-06: Terraform validate passed; plan and apply created exactly
four resources, followed by one DNS alias; zero existing resource changes/deletions. Runtime ESO/RDS
checks remain part of the live migration test, not implied by Terraform success.

Rollback: first return delivery to the previous backend and remove only the new
ESO Application through GitOps. Keep the remote Secret and application data.
Secret metadata has prevent_destroy and a 30-day recovery window; do not destroy
shared ESO CRDs, webhook, or existing platform/argocd controllers.
