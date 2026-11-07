# Oneport 플랫폼 서버

Oneport 플랫폼(화면·API·수집기)을 돌리는 EC2 한 대와 그 IAM 역할을 관리하는 스택입니다. 서버 안의 구성(docker compose, Caddy, 비밀 파일)과 CD 는 Hackathon 저장소 `platform/deploy/ec2`에 있습니다.

## 구성

| 자원 | 이름 | 비고 |
| --- | --- | --- |
| 인스턴스 | 태그 `Name=oneport-platform`, `project=oneport` | 도쿄(`ap-northeast-1`) 기본 VPC, `t3.small` 온디맨드, AL2023, gp3 20GiB 암호화, IMDSv2 필수 |
| 고정 IP | 태그 `Name=oneport-platform` | 플랫폼·홈랩 앱 도메인의 A 레코드. `eks` 스택이 API 허용 목록에 더한다 |
| 보안그룹 | `oneport-platform-sg` | 80(Let's Encrypt·HTTPS 리다이렉트), 443(접속 PIN 뒤 화면), 8443/tcp·51820/udp(온프렘 환경 연결 중계). SSH 는 열지 않고 SSM 으로 관리한다 |
| 서버 역할 | `ghost-oneport-platform-ec2` | SSM, 서울 ECR `ghost/oneport-platform-*` 읽기, 비용 화면용 읽기 |
| 배포 역할 | `ghost-oneport-platform-deploy` | GitHub OIDC 로 Hackathon main 만 맡는다. ECR push, 이 리전의 `project=oneport` 인스턴스에만 SSM 명령 |

서울 계정의 온디맨드 vCPU 한도(8)를 EKS 노드 3대와 Tailscale 라우터가 다 쓰고 있어서, 한도가 따로 매겨지는 도쿄에 둡니다. 홈랩까지는 Tailscale 로 40ms 안팎입니다.

- 역할은 팀 규칙대로 이름이 `ghost-`로 시작하고 권한 경계 `GhostWorkloadBoundary`를 붙입니다.
- IAM 태그 키는 대소문자를 구분하지 않아 기본 태그 `Project`와 `project`가 부딪힙니다. `project=oneport`는 EC2 자원에만 붙입니다. CD 의 SSM 권한이 인스턴스의 이 태그로 대상을 좁힙니다.
- 인스턴스의 `ami`, `user_data`는 처음 만들 때만 쓰여서 이후 변경을 무시합니다. 부팅 스크립트는 Hackathon 저장소 `platform/deploy/ec2/user-data.sh`입니다.

## 처음 만들 때와 import

처음에는 콘솔·CLI 로 만들었고 2026-11-07 이 스택으로 import 했습니다. 다시 import 할 때는 실제 ID 를 조회해서 넣습니다(저장소에 ID 를 적지 않습니다).

```sh
cd infra/oneport-platform
terraform init -backend-config=../backend.hcl -lockfile=readonly -input=false
terraform import aws_iam_role.server ghost-oneport-platform-ec2
terraform import aws_iam_role_policy_attachment.server_ssm ghost-oneport-platform-ec2/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
terraform import aws_iam_role_policy.server_ecr ghost-oneport-platform-ec2:ecr-pull-oneport
terraform import aws_iam_role_policy.server_cost ghost-oneport-platform-ec2:oneport-cost-read
terraform import aws_iam_instance_profile.server ghost-oneport-platform-ec2
terraform import aws_iam_role.deploy ghost-oneport-platform-deploy
terraform import aws_iam_role_policy.deploy ghost-oneport-platform-deploy:deploy-oneport-ec2
terraform import aws_security_group.server <보안그룹 ID>
terraform import aws_instance.server <인스턴스 ID>
terraform import aws_eip.server <EIP 할당 ID>
terraform plan   # No changes 여야 한다
```

import 뒤 plan 의 차이는 기본 태그 추가와, 전체 허용과 겹치던 사무실 IP 443 규칙 삭제뿐이었고 그대로 적용했습니다.

## EKS API 허용 목록

`eks` 스택은 이 스택의 `eks_public_access_cidrs` 출력을 `public_access_cidrs`에 합칩니다. 운영자 tfvars 에 플랫폼 서버 주소를 따로 적지 않아도, `eks`를 다시 apply 할 때 빠지지 않습니다. 이 스택 상태가 없으면 빈 목록으로 읽습니다.

서버를 다시 만들어 고정 IP 가 바뀌면 이 스택을 apply 한 뒤 `eks`도 plan·apply 해서 허용 목록을 맞추고, 도메인 A 레코드도 바꿉니다.
