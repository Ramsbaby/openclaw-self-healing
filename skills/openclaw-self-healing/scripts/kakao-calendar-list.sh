#!/bin/bash
# Kakao Calendar 일정 조회 스크립트

set -e

# 환경변수 체크
if [ -z "$KAKAO_ACCESS_TOKEN" ]; then
    echo "❌ KAKAO_ACCESS_TOKEN 환경변수가 필요합니다."
    exit 1
fi

# 파라미터: today | week | month
RANGE="${1:-today}"

# 날짜 계산 (KST → UTC 변환)
case "$RANGE" in
    today)
        # 오늘 00:00 ~ 23:59 (KST → UTC: -9시간)
        FROM=$(date -u -v-9H -v0H -v0M -v0S +"%Y-%m-%dT%H:%M:%SZ")
        TO=$(date -u -v-9H -v23H -v59M -v59S +"%Y-%m-%dT%H:%M:%SZ")
        ;;
    week)
        # 이번 주 (월~일)
        FROM=$(date -u -v-9H -v-mon -v0H -v0M -v0S +"%Y-%m-%dT%H:%M:%SZ")
        TO=$(date -u -v-9H -v+6d -v23H -v59M -v59S +"%Y-%m-%dT%H:%M:%SZ")
        ;;
    month)
        # 이번 달
        FROM=$(date -u -v-9H -v1d -v0H -v0M -v0S +"%Y-%m-%dT%H:%M:%SZ")
        TO=$(date -u -v-9H -v+1m -v1d -v-1d -v23H -v59M -v59S +"%Y-%m-%dT%H:%M:%SZ")
        ;;
    *)
        echo "❌ 사용법: $0 [today|week|month]"
        exit 1
        ;;
esac

# API 호출
RESPONSE=$(curl -s -X GET "https://kapi.kakao.com/v2/api/calendar/events" \
  -H "Authorization: Bearer $KAKAO_ACCESS_TOKEN" \
  -G \
  --data-urlencode "calendar_id=primary" \
  --data-urlencode "from=$FROM" \
  --data-urlencode "to=$TO" \
  --data-urlencode "limit=100")

# 결과 확인
if echo "$RESPONSE" | jq -e '.events' > /dev/null 2>&1; then
    EVENT_COUNT=$(echo "$RESPONSE" | jq '.events | length')
    
    if [ "$EVENT_COUNT" -eq 0 ]; then
        echo "📅 일정이 없습니다."
        exit 0
    fi
    
    echo "📅 일정 $EVENT_COUNT개 조회됨"
    echo ""
    
    # 일정 출력
    echo "$RESPONSE" | jq -r '.events[] | 
        "제목: \(.title)\n시작: \(.time.start_at)\n종료: \(.time.end_at)\n---"'
else
    echo "❌ 일정 조회 실패"
    echo "$RESPONSE" | jq '.'
    exit 1
fi
