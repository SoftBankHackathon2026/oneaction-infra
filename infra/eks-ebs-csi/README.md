# EBS CSI 드라이버 · 모니터링 StorageClass

gitops의 kube-prometheus-stack(`argocd/monitoring-aws.yaml`)은 Prometheus·Grafana 볼륨을
`oneaction-monitoring-gp3` StorageClass로 요청합니다. 이 스택은 그 전제를 코드로 만듭니다.

| 항목 | 값 |
| --- | --- |
| EKS 애드온 | `aws-ebs-csi-driver` `v1.67.2-eksbuild.1` (Kubernetes 1.36 기본 버전) |
| 자격증명 | EKS Pod Identity, `kube-system/ebs-csi-controller-sa` → `oneaction-ebs-csi-driver` |
| IAM 정책 | AWS 관리형 `AmazonEBSCSIDriverPolicy` |
| StorageClass | `oneaction-monitoring-gp3` (gp3, 암호화, `Retain`, `WaitForFirstConsumer`) |

`eks` 스택 뒤, gitops 모니터링 Application을 동기화하기 전에 적용합니다.

```bash
cd infra/eks-ebs-csi
terraform init -backend-config=../backend.hcl
terraform plan -out=tfplan && terraform apply tfplan
aws eks update-kubeconfig --name oneaction --region ap-northeast-2
kubectl apply -f manifests/storageclass-monitoring-gp3.yaml
kubectl -n kube-system rollout status deploy/ebs-csi-controller
```

`Retain`이므로 PVC를 지워도 EBS 볼륨이 남습니다. 환경을 정리할 때는 남은 `kubernetes.io/created-for/pvc/name`
태그의 볼륨을 따로 지웁니다.
