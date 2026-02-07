#!/bin/bash
# Self-Review V5.0 Logger
# =========================================
# 크론 종료 시 호출하여 메트릭 + 자기성찰 기록
#
# ⚠️ 주의: "자동 메트릭"은 거짓말입니다.
# duration과 tokens는 호출자가 제공해야 합니다.
# OpenClaw 크론은 이 값들을 자동으로 알 수 없습니다.
# =========================================
#
# Usage: self-review-logger.sh "크론명" "점수" "tokens_in" "tokens_out" "exit_status" \
#                               "what_went_wrong" "why" "next_action"
#
# 예시:
#   bash ~/openclaw/scripts/self-review-logger.sh \
#     "TQQQ 모니터링" "8.5" "100" "200" "ok" \
#     "지연 태그 누락" "습관" "다음부터 추가"

set -euo pipefail

# === 인자 파싱 ===
CRON_NAME="${1:-unknown}"
SCORE="${2:-0}"           # 1-10 점수 (LLM 자기평가)
TOKENS_IN="${3:-0}"       # 입력 토큰 (추정치 허용)
TOKENS_OUT="${4:-0}"      # 출력 토큰 (추정치 허용)
EXIT_STATUS="${5:-ok}"    # ok | error
WHAT_WENT_WRONG="${6:-없음}"
WHY="${7:-N/A}"
NEXT_ACTION="${8:-없음}"

# === 날짜/시간 ===
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H%M%S')
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# === 디렉토리 생성 ===
DIR=~/openclaw/memory/self-review/$DATE
mkdir -p "$DIR"

# === 안전한 파일명 생성 (타임스탬프 포함!) ===
# 이모지, 특수문자 제거 + 한글 유지
SAFE_NAME=$(echo "$CRON_NAME" | sed 's/[^가-힣a-zA-Z0-9_-]/_/g' | sed 's/__*/_/g' | sed 's/^_//' | sed 's/_$//')
if [ -z "$SAFE_NAME" ] || [ "$SAFE_NAME" = "_" ]; then
  SAFE_NAME="cron"
fi

# ✅ 타임스탬프 포함 → 덮어쓰기 방지
FILE="$DIR/${SAFE_NAME}_${TIME}.yaml"

# === 크론별 목표 로드 ===
TARGETS_FILE=~/openclaw/templates/targets-by-cron.yaml
DEFAULT_DURATION=15
DEFAULT_TOKENS=500

# 크론별 목표가 있으면 사용, 없으면 기본값
if [ -f "$TARGETS_FILE" ]; then
  # 간단한 grep 기반 조회 (yq 없이)
  CRON_DURATION=$(grep -A2 "^${SAFE_NAME}:" "$TARGETS_FILE" 2>/dev/null | grep "duration_sec:" | awk '{print $2}' || echo "")
  CRON_TOKENS=$(grep -A2 "^${SAFE_NAME}:" "$TARGETS_FILE" 2>/dev/null | grep "tokens:" | awk '{print $2}' || echo "")
fi

DURATION_GOAL="${CRON_DURATION:-$DEFAULT_DURATION}"
TOKENS_BUDGET="${CRON_TOKENS:-$DEFAULT_TOKENS}"

# === 목표 대비 계산 ===
# 점수 기반 판정 (duration 대신)
SCORE_MET="false"
if [ "$(echo "$SCORE >= 7" | bc -l)" -eq 1 ] 2>/dev/null; then
  SCORE_MET="true"
fi

# 토큰 사용률
if [ "$TOKENS_OUT" -gt 0 ] 2>/dev/null; then
  USAGE_PCT=$(echo "scale=1; $TOKENS_OUT / $TOKENS_BUDGET * 100" | bc)
else
  USAGE_PCT="0"
fi

# === YAML 생성 ===
cat > "$FILE" << EOF
# Self-Review V5.0
# Generated: $TIMESTAMP
# File: ${SAFE_NAME}_${TIME}.yaml

# === 메트릭 (호출자 제공) ===
# ⚠️ 이 값들은 "자동 수집"이 아닙니다.
# 크론이 종료 시 명시적으로 전달해야 합니다.
metrics:
  cron_name: "$CRON_NAME"
  timestamp: "$TIMESTAMP"
  score: $SCORE
  tokens_in: $TOKENS_IN
  tokens_out: $TOKENS_OUT
  exit_status: "$EXIT_STATUS"

# === LLM 자기성찰 ===
self_reflection:
  what_went_wrong: "$WHAT_WENT_WRONG"
  why: "$WHY"
  next_action: "$NEXT_ACTION"
  deadline: "$(date -v+7d '+%Y-%m-%d' 2>/dev/null || date -d '+7 days' '+%Y-%m-%d')"

# === 편향 점검 ===
# ⚠️ 기본값 true = 관대함 의심 (보수적 접근)
bias_check:
  am_i_being_too_easy: true
  evidence: "주간 리뷰에서 검증 필요"
  user_flagged_before: false

# === 목표 대비 ===
targets:
  score:
    goal: 7.0
    actual: $SCORE
    met: $SCORE_MET
  tokens:
    budget: $TOKENS_BUDGET
    actual: $TOKENS_OUT
    usage_pct: $USAGE_PCT

# === 메타 ===
meta:
  version: "5.0.1"
  reviewed_by: null
  review_date: null
EOF

echo "✅ Self-review logged: $FILE"
