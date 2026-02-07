#!/bin/bash
# 모닝 브리핑 스크립트
# 작성: 2026-02-07 (크론 간소화)

set -euo pipefail

# 색상 정의
RESET='\033[0m'
BOLD='\033[1m'

# 1. 관훈 여부 체크
OFFICE_LOC="사조"
if [ -f ~/openclaw/memory/gwanhun-state.json ]; then
  TODAY=$(date +%Y-%m-%d)
  STATE_DATE=$(jq -r '.date // ""' ~/openclaw/memory/gwanhun-state.json)
  if [ "$STATE_DATE" = "$TODAY" ]; then
    OFFICE_LOC="관훈"
  fi
fi

# 2. 좌표 설정
SX="126.9616"
SY="37.60277"
if [ "$OFFICE_LOC" = "관훈" ]; then
  EX="126.9857"
  EY="37.5707"
else
  EX="127.0644732"
  EY="37.5075404"
fi

# 3. 출근 경로 (Odsay API)
echo "## 🚇 출근 경로 (→ ${OFFICE_LOC})"
echo ""

ROUTES=$(curl -s -H "Referer: http://localhost/" \
  "https://api.odsay.com/v1/api/searchPubTransPathT?SX=${SX}&SY=${SY}&EX=${EX}&EY=${EY}&apiKey=4%2FoBienvoQ%2BufPGJf9lqlg" \
  | jq -r '.result.path[0:3] | to_entries | map(
    "\n### 경로 \(.key + 1)\n" +
    "⏱️ **\(.value.info.totalTime)분** | 💰 \(.value.info.payment)원 | 🔄 환승 \(.value.info.busTransitCount + .value.info.subwayTransitCount)회\n\n" +
    (.value.subPath | map(
      if .trafficType == 1 then
        "🚇 \(.lane[0].name) (\(.startName) → \(.endName), \(.stationCount)정거장)"
      elif .trafficType == 2 then
        "🚌 \(.lane[0].busNo) (\(.startName) → \(.endName), \(.stationCount)정거장)"
      elif .trafficType == 3 then
        "🚶 도보 \(.distance)m (\(.sectionTime)분)"
      else ""
      end
    ) | join("\n"))
  ) | join("\n")' 2>/dev/null || echo "경로 조회 실패")

echo "$ROUTES"
echo ""

# 4. 날씨
echo "## 🌡️ 날씨"
echo ""
curl -s "https://wttr.in/Seoul?format=j1" | jq -r '
  .current_condition[0] | 
  "🌡️ 기온: \(.temp_C)°C (체감 \(.FeelsLikeC)°C)\n" +
  "☁️ 날씨: \(.weatherDesc[0].value)\n" +
  "💨 바람: \(.windspeedKmph)km/h\n" +
  "💧 습도: \(.humidity)%"
' 2>/dev/null || echo "날씨 조회 실패"
echo ""

# 5. 복장 조언
TEMP=$(curl -s "https://wttr.in/Seoul?format=%t" | sed 's/[^0-9-]//g')
echo "**복장 조언:**"
if [ "$TEMP" -lt 0 ]; then
  echo "패딩 + 목도리 필수"
elif [ "$TEMP" -lt 10 ]; then
  echo "두꺼운 코트"
elif [ "$TEMP" -lt 15 ]; then
  echo "가벼운 외투"
elif [ "$TEMP" -lt 20 ]; then
  echo "긴팔"
else
  echo "반팔"
fi
echo ""

# 6. 오늘 일정
echo "## 📅 오늘 일정"
echo ""
gog cal today 2>/dev/null || echo "일정 없음"
echo ""

# 7. 시스템 사용량
echo "## 💻 시스템 상태"
echo ""
echo "**Mac mini:**"
echo "- CPU: $(top -l 1 | grep 'CPU usage' | awk '{print $3}')"
echo "- 메모리: $(memory_pressure | grep 'System-wide memory free percentage' | awk '{print 100-$5"%"}')"
echo "- 디스크: $(df -h / | tail -1 | awk '{print $5}')"
echo ""

# 8. Claude 한도
echo "**Claude 한도:**"
bash ~/openclaw/scripts/claude-weekly-usage.sh 2>/dev/null || echo "체크 실패"
echo ""

exit 0
