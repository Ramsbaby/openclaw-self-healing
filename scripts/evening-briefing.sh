#!/bin/bash
# 퇴근 브리핑 스크립트
# 작성: 2026-02-07 (크론 간소화)

set -euo pipefail

# Load self-review library (V5.0.1 AOP)
# shellcheck source=/dev/null
source "$(dirname "$0")/../lib/self-review-lib.sh"

# Self-review metrics
START_TIME=$(date +%s)

# Main briefing logic
main() {

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
EX="126.9616"
EY="37.60277"
if [ "$OFFICE_LOC" = "관훈" ]; then
  SX="126.9857"
  SY="37.5707"
else
  SX="127.0644732"
  SY="37.5075404"
fi

# 3. 귀가 경로 (Odsay API)
echo "## 🏠 귀가 경로 (${OFFICE_LOC} →)"
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

# 4. 현재 날씨
echo "## 🌡️ 현재 날씨"
echo ""
curl -s "https://wttr.in/Seoul?format=j1" | jq -r '
  .current_condition[0] | 
  "🌡️ 기온: \(.temp_C)°C (체감 \(.FeelsLikeC)°C)\n" +
  "☁️ 날씨: \(.weatherDesc[0].value)\n" +
  "💨 바람: \(.windspeedKmph)km/h\n" +
  "💧 습도: \(.humidity)%"
' 2>/dev/null || echo "날씨 조회 실패"
echo ""

# 5. TQQQ 종가
echo "## 📈 TQQQ 종가"
echo ""
python3 ~/openclaw/scripts/tqqq-yahoo-monitor.py 2>/dev/null | grep -E "현재가|변동|평가금액|수익" || echo "시세 조회 실패"
echo ""

# 6. 내일 일정
echo "## 📅 내일 일정"
echo ""
gog cal tomorrow 2>/dev/null || echo "일정 없음"
echo ""

# 7. 시스템 상태
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

return 0
}

# Run main function
main
MAIN_EXIT_CODE=$?

# ============================================
# Self-Review (V5.0.1)
# ============================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Non-AI cron (script-based briefing) → tokens=0
INPUT_TOKENS=0
OUTPUT_TOKENS=0

# Determine status
if [ $MAIN_EXIT_CODE -eq 0 ]; then
  STATUS="ok"
  WHAT_WENT_WRONG="없음"
  WHY="브리핑 생성 성공"
  NEXT_ACTION="없음"
else
  STATUS="fail"
  WHAT_WENT_WRONG="브리핑 실패 (exit code: $MAIN_EXIT_CODE)"
  WHY="스크립트 에러"
  NEXT_ACTION="로그 확인 필요"
fi

# Log self-review
sr_log_review \
  "Evening Briefing" \
  "$DURATION" \
  "$INPUT_TOKENS" \
  "$OUTPUT_TOKENS" \
  "$STATUS" \
  "$WHAT_WENT_WRONG" \
  "$WHY" \
  "$NEXT_ACTION"

exit $MAIN_EXIT_CODE
