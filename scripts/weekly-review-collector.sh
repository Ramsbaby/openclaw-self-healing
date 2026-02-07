#!/bin/bash
# Weekly Review Collector for V5.0 Layer 3
# 지난 7일간의 self-review 데이터를 수집하여 요약

set -euo pipefail

echo "# 주간 자기평가 요약 (V5.0 Layer 3)"
echo "# 생성일: $(date '+%Y-%m-%d %H:%M')"
echo "# 분석 대상: 지난 7일"
echo ""

REVIEW_DIR=~/openclaw/memory/self-review
TOTAL_REVIEWS=0
DURATION_FAILURES=0
EASY_REVIEWS=0

echo "## 📊 통계"
echo ""

# 지난 7일 데이터 수집
for i in {0..6}; do
  DATE=$(date -v-${i}d '+%Y-%m-%d' 2>/dev/null || date -d "-${i} days" '+%Y-%m-%d')
  DAY_DIR="$REVIEW_DIR/$DATE"
  
  if [ -d "$DAY_DIR" ]; then
    COUNT=$(ls -1 "$DAY_DIR"/*.yaml 2>/dev/null | wc -l | tr -d ' ')
    TOTAL_REVIEWS=$((TOTAL_REVIEWS + COUNT))
    
    # 목표 미달 카운트
    FAILED=$(grep -l "met: false" "$DAY_DIR"/*.yaml 2>/dev/null | wc -l | tr -d ' ')
    DURATION_FAILURES=$((DURATION_FAILURES + FAILED))
    
    # 너무 관대한 평가 카운트
    EASY=$(grep -l "am_i_being_too_easy: true" "$DAY_DIR"/*.yaml 2>/dev/null | wc -l | tr -d ' ')
    EASY_REVIEWS=$((EASY_REVIEWS + EASY))
  fi
done

echo "- 총 자기평가 수: $TOTAL_REVIEWS"
echo "- 목표 미달 (duration): $DURATION_FAILURES"
echo "- 관대한 평가 인정: $EASY_REVIEWS"
echo ""

# 개선 항목 수집
echo "## 🔧 개선 항목 목록"
echo ""

for i in {0..6}; do
  DATE=$(date -v-${i}d '+%Y-%m-%d' 2>/dev/null || date -d "-${i} days" '+%Y-%m-%d')
  DAY_DIR="$REVIEW_DIR/$DATE"
  
  if [ -d "$DAY_DIR" ]; then
    for file in "$DAY_DIR"/*.yaml 2>/dev/null; do
      if [ -f "$file" ]; then
        CRON=$(grep "cron_name:" "$file" | cut -d'"' -f2)
        WRONG=$(grep "what_went_wrong:" "$file" | cut -d'"' -f2)
        ACTION=$(grep "next_action:" "$file" | cut -d'"' -f2)
        
        if [ "$WRONG" != "없음" ] && [ -n "$WRONG" ]; then
          echo "### $DATE - $CRON"
          echo "- 문제: $WRONG"
          echo "- 액션: $ACTION"
          echo ""
        fi
      fi
    done
  fi
done

echo "## 🎯 외부 검증 질문"
echo ""
echo "1. 이번 주 자기평가들이 너무 관대했는가?"
echo "2. 같은 실수가 반복되고 있는가?"
echo "3. 개선 항목이 실제로 적용됐는가?"
echo "4. 다음 주 집중해야 할 영역은?"
