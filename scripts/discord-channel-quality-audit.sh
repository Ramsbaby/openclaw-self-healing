#!/bin/bash
# Discord 채널별 응답 품질 감사
# V3 systemPrompt 준수율 자동 평가

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/openclaw}"
AUDIT_LOG="$WORKSPACE/memory/channel-quality-audit-$(date +%Y-%m-%d).md"

# 평가 기준 (V3 systemPrompt 기반)
declare -A CHANNEL_NAMES=(
  ["1468386844621144065"]="jarvis"
  ["1469190686145384513"]="market"
  ["1469190688083280065"]="system"
  ["1469905074661757049"]="dev"
)

declare -A REQUIRED_ELEMENTS=(
  ["jarvis"]="도구 호출 3회 이상 시 중간 보고|2000자 분할|실패 처리"
  ["market"]="현재가 USD+KRW|변동률|일중 범위|Stop-Loss 거리|데이터 출처|타임스탬프"
  ["system"]="긴급도 이모지|로그 10줄 제한|중복 억제|민감 정보 마스킹"
  ["dev"]="코드블록 언어 명시|5단계 에러 분석|성능 지표|ChatGPT 톤 금지"
)

echo "# Discord 채널별 응답 품질 감사" > "$AUDIT_LOG"
echo "" >> "$AUDIT_LOG"
echo "**날짜:** $(date '+%Y-%m-%d %H:%M KST')" >> "$AUDIT_LOG"
echo "**기간:** 최근 7일" >> "$AUDIT_LOG"
echo "" >> "$AUDIT_LOG"

# Discord 메시지 검색 (최근 7일)
for channel_id in "${!CHANNEL_NAMES[@]}"; do
  channel_name="${CHANNEL_NAMES[$channel_id]}"
  requirements="${REQUIRED_ELEMENTS[$channel_name]}"
  
  echo "## #jarvis-$channel_name" >> "$AUDIT_LOG"
  echo "" >> "$AUDIT_LOG"
  
  # 메시지 검색 (최근 7일, 자비스 메시지만)
  messages=$(openclaw message action:search \
    guildId:483238980280647680 \
    channelId:"$channel_id" \
    authorId:1468381693613445275 \
    limit:50 2>/dev/null || echo "[]")
  
  total_count=$(echo "$messages" | jq '. | length')
  
  if [ "$total_count" -eq 0 ]; then
    echo "- 메시지 없음 (최근 7일)" >> "$AUDIT_LOG"
    echo "" >> "$AUDIT_LOG"
    continue
  fi
  
  echo "- 총 메시지: $total_count" >> "$AUDIT_LOG"
  
  # 필수 요소 체크
  IFS='|' read -ra ELEMENTS <<< "$requirements"
  pass_count=0
  
  for element in "${ELEMENTS[@]}"; do
    # 간단한 패턴 매칭 (실제로는 더 정교한 분석 필요)
    case "$element" in
      "현재가 USD+KRW")
        pattern="USD.*KRW|\\$.*₩"
        ;;
      "변동률")
        pattern="±.*%|[+-][0-9]+\.[0-9]+%"
        ;;
      "긴급도 이모지")
        pattern="🚨|⚠️|ℹ️|✅"
        ;;
      "코드블록 언어 명시")
        pattern="\`\`\`(python|bash|javascript|typescript)"
        ;;
      *)
        pattern=$(echo "$element" | sed 's/ /.*/g')
        ;;
    esac
    
    match_count=$(echo "$messages" | jq -r '.[].content' | grep -cE "$pattern" || true)
    compliance=$(awk "BEGIN {printf \"%.1f\", ($match_count / $total_count) * 100}")
    
    echo "  - $element: ${compliance}% ($match_count/$total_count)" >> "$AUDIT_LOG"
    
    if (( $(echo "$compliance >= 80" | bc -l) )); then
      ((pass_count++))
    fi
  done
  
  # 종합 점수
  total_elements=${#ELEMENTS[@]}
  overall_score=$(awk "BEGIN {printf \"%.1f\", ($pass_count / $total_elements) * 100}")
  
  echo "" >> "$AUDIT_LOG"
  if (( $(echo "$overall_score >= 80" | bc -l) )); then
    echo "**종합:** ✅ ${overall_score}% 통과 ($pass_count/$total_elements)" >> "$AUDIT_LOG"
  else
    echo "**종합:** ⚠️ ${overall_score}% 미달 ($pass_count/$total_elements)" >> "$AUDIT_LOG"
  fi
  echo "" >> "$AUDIT_LOG"
done

# 개선 제안
echo "## 개선 제안" >> "$AUDIT_LOG"
echo "" >> "$AUDIT_LOG"
echo "- 80% 미만 항목: systemPrompt 강화 또는 수동 교정 필요" >> "$AUDIT_LOG"
echo "- 반복 위반: 자동 검증 스크립트 추가 고려" >> "$AUDIT_LOG"
echo "" >> "$AUDIT_LOG"

# Discord 알림
cat "$AUDIT_LOG"
