#!/usr/bin/env bash
# gsd-worklog.sh — M/S/T 단위 worklog 문서 스캐폴딩
#
#   scripts/gsd-worklog.sh unit M001                → M001/ + M001-PLAN.md
#   scripts/gsd-worklog.sh unit M001/S001           → S001/ + S001-PLAN.md
#   scripts/gsd-worklog.sh unit M001/S001/T003      → T003/ + T003-PLAN.md
#   scripts/gsd-worklog.sh checklist M001/S001/T003 → T003-CHECKLIST-P{next}.md
#   scripts/gsd-worklog.sh brief M001/S001/T003     → T003-BRIEF.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WL="$ROOT/docs/gsd-worklog"
TPL="$WL/_templates"
TODAY="$(date +%Y-%m-%d)"

usage() { sed -n '2,8p' "$0"; exit 1; }
[[ $# -ge 2 ]] || usage

CMD="$1"; UNIT_PATH="$2"
UNIT_ID="$(basename "$UNIT_PATH")"
PARENT_ID="$(basename "$(dirname "$UNIT_PATH")")"
[[ "$PARENT_ID" == "." ]] && PARENT_ID="(none)"

IFS='/' read -r -a SEGS <<< "$UNIT_PATH"
EXPECT=(M S T)
for i in "${!SEGS[@]}"; do
  [[ $i -lt 3 ]] || { echo "오류: 위계는 최대 M/S/T 3단계입니다." >&2; exit 1; }
  [[ "${SEGS[$i]}" =~ ^${EXPECT[$i]}[0-9]{3}$ ]] || {
    echo "오류: '${SEGS[$i]}' 는 '${EXPECT[$i]}NNN' 형식이어야 합니다 (예: ${EXPECT[$i]}001)." >&2
    exit 1
  }
done

DIR="$WL/$UNIT_PATH"

# Graph View 연결용 위키링크 (동명 파일 중복 대비, Vault 루트 기준 경로 포함)
REL_DIR="docs/gsd-worklog/$UNIT_PATH"
if [[ "$PARENT_ID" == "(none)" ]]; then
  PARENT_LINK="[[WORKFLOW]]"   # M 단위의 상위 = 플로우 허브
else
  PARENT_LINK="[[docs/gsd-worklog/$(dirname "$UNIT_PATH")/$PARENT_ID-PLAN|$PARENT_ID-PLAN]]"
fi
PLAN_LINK="[[$REL_DIR/$UNIT_ID-PLAN|$UNIT_ID-PLAN]]"

render() {
  local tpl="$1" out="$2" attempt="${3:-1}"
  local check_link="[[$REL_DIR/$UNIT_ID-CHECKLIST-P$attempt|$UNIT_ID-CHECKLIST-P$attempt]]"
  sed -e "s#{{UNIT_ID}}#$UNIT_ID#g" \
      -e "s#{{PARENT_ID}}#$PARENT_ID#g" \
      -e "s#{{PARENT_LINK}}#$PARENT_LINK#g" \
      -e "s#{{PLAN_LINK}}#$PLAN_LINK#g" \
      -e "s#{{CHECK_LINK}}#$check_link#g" \
      -e "s#{{DATE}}#$TODAY#g" \
      -e "s#{{ATTEMPT}}#$attempt#g" \
      "$tpl" > "$out"
  echo "생성: ${out#$ROOT/}"
}

case "$CMD" in
  unit)
    mkdir -p "$DIR"
    if [[ -f "$DIR/$UNIT_ID-PLAN.md" ]]; then
      echo "이미 존재: $UNIT_PATH/$UNIT_ID-PLAN.md" >&2; exit 1
    fi
    render "$TPL/PLAN.md" "$DIR/$UNIT_ID-PLAN.md"
    ;;
  checklist)
    [[ -d "$DIR" ]] || { echo "오류: 단위 '$UNIT_PATH' 가 없습니다. 먼저 'unit'으로 생성하세요." >&2; exit 1; }
    next=1
    while [[ -f "$DIR/$UNIT_ID-CHECKLIST-P$next.md" ]]; do next=$((next+1)); done
    render "$TPL/CHECKLIST.md" "$DIR/$UNIT_ID-CHECKLIST-P$next.md" "$next"
    ;;
  brief)
    [[ -d "$DIR" ]] || { echo "오류: 단위 '$UNIT_PATH' 가 없습니다." >&2; exit 1; }
    last=0
    while [[ -f "$DIR/$UNIT_ID-CHECKLIST-P$((last+1)).md" ]]; do last=$((last+1)); done
    [[ $last -ge 1 ]] || { echo "오류: CHECKLIST가 1개 이상 있어야 BRIEF를 작성할 수 있습니다." >&2; exit 1; }
    [[ -f "$DIR/$UNIT_ID-BRIEF.md" ]] && { echo "이미 존재: $UNIT_ID-BRIEF.md" >&2; exit 1; }
    render "$TPL/BRIEF.md" "$DIR/$UNIT_ID-BRIEF.md" "$last"
    ;;
  *) usage ;;
esac
