#!/bin/bash
# Discord 채널별 FAQ 자동 학습 및 템플릿 생성
# 자주 묻는 질문 패턴 감지 → 표준 응답 템플릿 생성

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/openclaw}"
FAQ_DIR="$WORKSPACE/memory/channel-faq"
mkdir -p "$FAQ_DIR"

declare -A CHANNEL_NAMES=(
  ["1468386844621144065"]="jarvis"
  ["1469190686145384513"]="market"
  ["1469190688083280065"]="system"
  ["1469905074661757049"]="dev"
)

echo "🔍 채널별 FAQ 패턴 분석 시작..."

for channel_id in "${!CHANNEL_NAMES[@]}"; do
  channel_name="${CHANNEL_NAMES[$channel_id]}"
  faq_file="$FAQ_DIR/${channel_name}-faq.md"
  
  echo "## #jarvis-$channel_name FAQ 분석 중..."
  
  # 최근 30일 메시지 검색 (정우님 메시지만)
  user_messages=$(openclaw message action:search \
    guildId:483238980280647680 \
    channelId:"$channel_id" \
    authorId:364093757018079234 \
    limit:100 2>/dev/null || echo "[]")
  
  # 메시지 빈도 분석 (간단한 키워드 기반)
  keywords=$(echo "$user_messages" | jq -r '.[].content' | \
    tr '[:upper:]' '[:lower:]' | \
    grep -oE '\w{3,}' | \
    sort | uniq -c | sort -rn | head -10)
  
  # FAQ 파일 생성
  cat > "$faq_file" <<EOF
# #jarvis-$channel_name FAQ

**생성일:** $(date '+%Y-%m-%d %H:%M KST')
**분석 기간:** 최근 30일

## 자주 묻는 질문 패턴

$(echo "$keywords" | awk '{print "- **" $2 "** (" $1 "회)"}')

## 표준 응답 템플릿

### 패턴 1: [자동 생성 예정]
**질문:** TBD
**응답 템플릿:** TBD

---

**참고:** 이 FAQ는 자동 생성되었습니다. 수동 편집 가능합니다.
EOF
  
  echo "  → $faq_file 생성 완료"
done

echo ""
echo "✅ FAQ 분석 완료"
echo "📁 저장 위치: $FAQ_DIR"
echo ""
echo "**다음 단계:**"
echo "1. 각 FAQ 파일 검토"
echo "2. 표준 응답 템플릿 추가"
echo "3. systemPrompt에 FAQ 참조 추가"
