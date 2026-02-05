#!/bin/bash
# Kakao Calendar 일정 추가 스크립트

set -e

# 환경변수 체크
if [ -z "$KAKAO_ACCESS_TOKEN" ]; then
    echo "❌ KAKAO_ACCESS_TOKEN 환경변수가 필요합니다."
    exit 1
fi

# 파라미터
TITLE="$1"
START_AT="$2"  # UTC format: 2026-02-11T00:00:00Z
END_AT="$3"    # UTC format: 2026-02-11T23:59:59Z
ALL_DAY="${4:-true}"
DESCRIPTION="${5:-}"

if [ -z "$TITLE" ] || [ -z "$START_AT" ] || [ -z "$END_AT" ]; then
    echo "❌ 사용법: $0 <제목> <시작시각(UTC)> <종료시각(UTC)> [all_day] [설명]"
    echo "예시: $0 '합동생일' '2026-02-11T00:00:00Z' '2026-02-11T23:59:59Z' true"
    exit 1
fi

# JSON 생성
EVENT_JSON=$(cat << EOF
{
  "title": "$TITLE",
  "time": {
    "start_at": "$START_AT",
    "end_at": "$END_AT",
    "time_zone": "Asia/Seoul",
    "all_day": $ALL_DAY,
    "lunar": false
  }$([ -n "$DESCRIPTION" ] && echo ",
  \"description\": \"$DESCRIPTION\"" || echo "")
}
EOF
)

# API 호출
RESPONSE=$(curl -s -X POST "https://kapi.kakao.com/v2/api/calendar/create/event" \
  -H "Authorization: Bearer $KAKAO_ACCESS_TOKEN" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "calendar_id=primary" \
  --data-urlencode "event=$EVENT_JSON")

# 결과 확인
if echo "$RESPONSE" | jq -e '.event_id' > /dev/null 2>&1; then
    EVENT_ID=$(echo "$RESPONSE" | jq -r '.event_id')
    echo "✅ 일정 추가 완료"
    echo "제목: $TITLE"
    echo "시작: $START_AT"
    echo "종료: $END_AT"
    echo "ID: $EVENT_ID"
else
    echo "❌ 일정 추가 실패"
    echo "$RESPONSE" | jq '.'
    exit 1
fi
