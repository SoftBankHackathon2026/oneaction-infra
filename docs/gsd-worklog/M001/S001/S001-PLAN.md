---
unit: "S001"
type: PLAN
parent: "[[docs/gsd-worklog/M001/M001-PLAN|M001-PLAN]]"
created: "2026-11-04"
status: in-progress
---

# S001 PLAN

> 상위 단위: [[docs/gsd-worklog/M001/M001-PLAN|M001-PLAN]] · 플로우 허브: [[WORKFLOW]]

## 1. 작업 개요
- GCP 인프라와 배포 연결 구성. 사용자가 main 분기, GCP 구현, origin push, main 대상 초안 변경 요청 작성을 명시적으로 요청했습니다.
- 기존 AWS 리소스와 상태는 변경하지 않습니다. 클라우드별 리소스는 분리하고 중립적인 설치 설정은 재사용합니다.

## 2. 이전 진행상황
- 기준: origin/main 90968d3c8bda2233324381753d70c8b2e931d79f.
- 이 저장소에는 AGENTS.md, WORKFLOW.md, worklog 도구가 없었습니다. 세션의 작업 규약에 따라 문서 생성 도구와 템플릿을 가져왔습니다.
- 현재 Aolda 저장소의 WORKFLOW 단계 2는 다른 프로젝트이므로 변경하지 않습니다. 이 저장소 구현은 사용자의 직접 지시에 근거합니다.

## 3. 구현 목표
- AWS 대응 network/storage/dns/database/gke/load-balancer/observability/kafka/secrets 구성.
- GCP 전용 상태, 프로젝트/환경 변수, 최소 권한 Workload Identity, 사설 데이터 계층.
- 클라우드 실제 생성은 하지 않으며 정적 검증·모의 공급자 계획 검사와 독립 검증 증거를 남깁니다.

## 4. 구성 하위작업 단위

| 하위 단위 | 목적 | 담당 역할 | 배치 모델 |
| --- | --- | --- | --- |
| [[docs/gsd-worklog/M001/S001/T001/T001-PLAN|T001]] | Terraform 리소스·부정 입력 시험 | 주 에이전트 구현 / 별도 에이전트 독립 검증 | 현재 Codex 모델(상속, provider OpenAI) |
| [[docs/gsd-worklog/M001/S001/T002/T002-PLAN|T002]] | 공통 설치 재사용·문서·배포 연결 | 주 에이전트 구현 / 별도 에이전트 독립 검증 | 현재 Codex 모델(상속, provider OpenAI) |

## 5. TDD 전략
- RED: 존재하지 않는 GCP 출력·배포 연결 계약을 참조하는 시험을 먼저 실행하여 실패 로그 기록.
- GREEN: 공식 Google 공급자 스키마로 구성하고 terraform validate/test 및 Python 단위 시험 실행.
- REFACTOR: 기능별 모듈과 기존 Helm values 재사용. 동일 시험 재실행.
- 모의 공급자(mock provider)는 API 스키마·계획 계약 검증이며 실제 GCP 연결/가용량/클러스터 동작 검증을 대신하지 않습니다.

## 6. 통과 기준
- [ ] Terraform 형식 검사, init -backend=false, validate, test가 통과하고 기본/선택 구성과 부정 입력을 확인.
- [ ] 기존 AWS 코드가 origin/main과 동일하고 GCP 상태가 분리됨.
- [ ] 비밀값이 Terraform 상태에 들어가지 않으며 권한은 목적별로 나뉨.
- [ ] 설치 렌더러 시험에서 재사용 values·GCP 인증·데이터베이스 프록시·로드밸런서·선택 기능을 확인.
- [ ] 적용 순서, 수동 입력, Kafka 인증 차이, 실제 배포 미검증 범위를 문서에 명시.
- [ ] 별도 검증 에이전트가 CHECKLIST를 작성하고 실패 항목 보완 후 BRIEF 작성.
