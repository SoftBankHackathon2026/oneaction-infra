---
unit: "{{UNIT_ID}}"
type: CHECKLIST
attempt: {{ATTEMPT}}
plan: "{{PLAN_LINK}}"
verified_by: "<검증 에이전트 식별자 (세션/모델)>"
created: "{{DATE}}"
result: pending   # pass | fail
---

# {{UNIT_ID}} CHECKLIST — P{{ATTEMPT}}

> 대상 계획: {{PLAN_LINK}} · 상위 단위: {{PARENT_LINK}}
>
> 검증 에이전트는 {{PLAN_LINK}} §6 의 체크리스트를 **그대로 복사**하여
> 항목별로 판정한다. 판정 근거(실행 명령·로그·산출물 경로)를 반드시 남긴다.

## 판정 결과

| # | 통과 기준 | 판정 | 근거 (명령/로그/경로) |
| --- | --- | --- | --- |
| 1 | | ✅ / ❌ | |

## 종합 판정
- 결과: **PASS / FAIL**

## 보완계획 (FAIL 시에만 작성)
<!-- 실패 항목별로: 원인 → 보완 방법 → 다음 시도에서의 확인 방법 -->
