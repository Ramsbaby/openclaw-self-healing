#!/bin/bash
# Odsay API 대중교통 경로 조회

set -e

API_KEY="${ODSAY_API_KEY:-$(jq -r '.env.vars.ODSAY_API_KEY // empty' ~/.openclaw/openclaw.json)}"

if [ -z "$API_KEY" ]; then
    echo "❌ ODSAY_API_KEY 환경변수가 필요합니다."
    exit 1
fi

# 파라미터
START_ADDR="$1"
END_ADDR="$2"

if [ -z "$START_ADDR" ] || [ -z "$END_ADDR" ]; then
    echo "❌ 사용법: $0 <출발지> <도착지>"
    echo "예시: $0 '평창문화로 12' '영동대로 424'"
    exit 1
fi

# 1. 출발지 좌표 검색 (Kakao Local API 사용)
KAKAO_API_KEY="${KAKAO_REST_API_KEY:-4d7f36bbfa672c5e24582307de57f4e4}"
START_COORD=$(curl -s "https://dapi.kakao.com/v2/local/search/address.json?query=${START_ADDR}" \
  -H "Authorization: KakaoAK ${KAKAO_API_KEY}" | \
  jq -r '.documents[0] | "\(.x),\(.y)"')

END_COORD=$(curl -s "https://dapi.kakao.com/v2/local/search/address.json?query=${END_ADDR}" \
  -H "Authorization: KakaoAK ${KAKAO_API_KEY}" | \
  jq -r '.documents[0] | "\(.x),\(.y)"')

if [ "$START_COORD" = "null,null" ] || [ "$END_COORD" = "null,null" ]; then
    echo "❌ 주소를 찾을 수 없습니다."
    exit 1
fi

START_X=$(echo $START_COORD | cut -d',' -f1)
START_Y=$(echo $START_COORD | cut -d',' -f2)
END_X=$(echo $END_COORD | cut -d',' -f1)
END_Y=$(echo $END_COORD | cut -d',' -f2)

# 2. Odsay API로 경로 검색
RESPONSE=$(curl -s "https://api.odsay.com/v1/api/searchPubTransPathT?SX=${START_X}&SY=${START_Y}&EX=${END_X}&EY=${END_Y}&apiKey=${API_KEY}")

# 3. 결과 파싱
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo "❌ 경로 검색 실패"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

# 최적 경로 (첫 번째)
ROUTE=$(echo "$RESPONSE" | jq -r '.result.path[0]')

TOTAL_TIME=$(echo "$ROUTE" | jq -r '.info.totalTime')
PAYMENT=$(echo "$ROUTE" | jq -r '.info.payment')
BUS_TRANSIT=$(echo "$ROUTE" | jq -r '.info.busTransitCount')
SUBWAY_TRANSIT=$(echo "$ROUTE" | jq -r '.info.subwayTransitCount')
WALK_TIME=$(echo "$ROUTE" | jq -r '.info.totalWalk')

# 출력
cat << EOF
🚇 대중교통 경로

출발: ${START_ADDR}
도착: ${END_ADDR}

소요시간: ${TOTAL_TIME}분
요금: ${PAYMENT}원
환승: 버스 ${BUS_TRANSIT}회, 지하철 ${SUBWAY_TRANSIT}회
도보: ${WALK_TIME}분
EOF

# JSON 저장 (크론에서 사용)
echo "$ROUTE" > /tmp/odsay-route.json
