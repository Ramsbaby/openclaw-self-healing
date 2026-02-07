#!/bin/bash
# Self-Review V5.0 Logger
# 크론 종료 시 호출하여 자동 메트릭 + 자기성찰 기록
# Usage: self-review-logger.sh "크론명" "duration_sec" "tokens_in" "tokens_out" "exit_status" "what_went_wrong" "why" "next_action"

set -euo pipefail

CRON_NAME="${1:-unknown}"
DURATION_SEC="${2:-0}"
TOKENS_IN="${3:-0}"
TOKENS_OUT="${4:-0}"
EXIT_STATUS="${5:-ok}"
WHAT_WENT_WRONG="${6:-없음}"
WHY="${7:-N/A}"
NEXT_ACTION="${8:-없음}"

DATE=$(date '+%Y-%m-%d')
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
DIR=~/openclaw/memory/self-review/$DATE
mkdir -p "$DIR"

# 크론명에서 안전한 파일명 생성 (한글 유니코드 지원)
SAFE_NAME=$(echo "$CRON_NAME" | sed 's/[^가-힣a-zA-Z0-9_-]/_/g' | sed 's/__*/_/g')
if [ -z "$SAFE_NAME" ] || [ "$SAFE_NAME" = "_" ]; then
  SAFE_NAME="cron_$(date +%H%M%S)"
fi
FILE="$DIR/${SAFE_NAME}.yaml"

# 목표 대비 계산
DURATION_MET="false"
if (( $(echo "$DURATION_SEC < 15" | bc -l) )); then
  DURATION_MET="true"
fi

TOKENS_BUDGET=500
if [ "$TOKENS_OUT" -gt 0 ] 2>/dev/null; then
  USAGE_PCT=$(echo "scale=1; $TOKENS_OUT / $TOKENS_BUDGET * 100" | bc)
else
  USAGE_PCT="0"
fi

cat > "$FILE" << EOF
# Self-Review V5.0
# Generated: $TIMESTAMP

auto_metrics:
  cron_name: "$CRON_NAME"
  timestamp: "$TIMESTAMP"
  duration_sec: $DURATION_SEC
  tokens_in: $TOKENS_IN
  tokens_out: $TOKENS_OUT
  exit_status: "$EXIT_STATUS"

self_reflection:
  what_went_wrong: "$WHAT_WENT_WRONG"
  why: "$WHY"
  next_action: "$NEXT_ACTION"
  deadline: "$(date -v+7d '+%Y-%m-%d' 2>/dev/null || date -d '+7 days' '+%Y-%m-%d')"

bias_check:
  am_i_being_too_easy: false
  evidence: "자동 생성 - 주간 리뷰에서 검증 필요"
  user_flagged_before: false

targets:
  duration:
    goal_sec: 15
    met: $DURATION_MET
  tokens:
    budget: $TOKENS_BUDGET
    usage_pct: $USAGE_PCT

meta:
  version: "5.0"
  reviewed_by: null
  review_date: null
EOF

echo "✅ Self-review logged: $FILE"
