#!/bin/bash
# Healthchecks.io 자동 설정 스크립트
# API Key를 입력하면 7개 크론잡 체크를 자동 생성하고 healthchecks.json 업데이트
#
# 사전 준비:
#   1. https://healthchecks.io 가입 (무료, 20개 체크)
#   2. Settings → API Access → API key 복사
#
# 사용법: setup-healthchecks.sh <API_KEY>

set -euo pipefail

API_KEY="${1:-}"
HC_CONFIG="$HOME/.openclaw/healthchecks.json"
HC_API="https://healthchecks.io/api/v3"

if [[ -z "$API_KEY" ]]; then
    echo "============================================"
    echo "  Healthchecks.io 설정 가이드"
    echo "============================================"
    echo ""
    echo "1. https://healthchecks.io 가입 (GitHub 로그인 가능)"
    echo "2. Settings → API Access → API key (read-write) 복사"
    echo "3. 다시 실행:"
    echo "   ~/openclaw/scripts/setup-healthchecks.sh YOUR_API_KEY"
    echo ""
    exit 0
fi

echo "Healthchecks.io 체크 생성 중..."

# 크론잡 체크 정의 (이름, 스케줄, Grace Period(초))
declare -A CHECKS=(
    ["guardian"]="*/3 * * * *|300|LaunchAgent Guardian 감시"
    ["rate-monitor"]="*/5 * * * *|600|Discord Rate Limit 감시"
    ["latency-tracker"]="*/5 * * * *|600|Gateway 지연 추적"
    ["security-audit"]="0 2 * * *|7200|보안 감사"
    ["level2-tune"]="0 3 * * *|7200|Level 2 파라미터 자동튜닝"
    ["morning-standup"]="0 8 * * *|3600|통합 모닝 브리핑"
    ["maintenance"]="0 3 * * 0|86400|서버 정비 (일요일)"
)

# JSON 초기화
CHECKS_JSON="{}"

for slug in "${!CHECKS[@]}"; do
    IFS='|' read -r schedule grace desc <<< "${CHECKS[$slug]}"

    # API로 체크 생성
    response=$(curl -s -X POST "${HC_API}/checks/" \
        -H "X-Api-Key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"openclaw-${slug}\", \"slug\": \"openclaw-${slug}\", \"tags\": \"openclaw\", \"timeout\": 0, \"schedule\": \"${schedule}\", \"grace\": ${grace}, \"desc\": \"${desc}\", \"channels\": \"*\"}" 2>&1)

    uuid=$(echo "$response" | jq -r '.ping_url // empty' 2>/dev/null | sed 's|.*/||')

    if [[ -n "$uuid" ]] && [[ "$uuid" != "null" ]]; then
        echo "  ✓ ${slug} → ${uuid}"
        CHECKS_JSON=$(echo "$CHECKS_JSON" | jq --arg k "$slug" --arg v "$uuid" '. + {($k): $v}')
    else
        echo "  ✗ ${slug} 생성 실패: $(echo "$response" | jq -r '.error // "unknown"' 2>/dev/null)"
    fi
done

# healthchecks.json 업데이트
cat > "$HC_CONFIG" <<EOF
{
  "ping_url": "https://hc-ping.com",
  "checks": $(echo "$CHECKS_JSON" | jq '.')
}
EOF

echo ""
echo "✓ 설정 완료: $HC_CONFIG"
echo ""
echo "이제 크론탭에 자동 반영하려면:"
echo "  ~/openclaw/scripts/apply-healthchecks-to-cron.sh"
