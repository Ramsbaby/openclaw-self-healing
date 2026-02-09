#!/bin/bash
# FAQ Learner V1.0
# 채널별 반복 질문 패턴을 학습하고 FAQ 데이터베이스를 자동 업데이트
#
# 실행 빈도: 매일 오전 3시 (cron)
# 대상: 최근 7일간 Discord 대화
# 임계값: 동일 질문 3회 이상 시 FAQ 등록 제안

set -euo pipefail

OPENCLAW_DIR=~/openclaw
FAQ_DIR="$OPENCLAW_DIR/memory/faq"
ANALYSIS_LOG="$FAQ_DIR/analysis-$(date +%Y-%m-%d).log"

mkdir -p "$FAQ_DIR"

# 채널 목록 (bash 3.2 호환)
CHANNEL_LIST="jarvis:1468386844621144065 jarvis-market:1469190686145384513 jarvis-system:1469190688083280065 jarvis-dev:1469905074661757049"

# 각 채널별 FAQ 학습
for channel_pair in $CHANNEL_LIST; do
  channel_name="${channel_pair%%:*}"
  CHANNEL_ID="${channel_pair#*:}"
  FAQ_FILE="$FAQ_DIR/faq-${channel_name}.json"
  
  echo "📚 채널: #${channel_name} (${CHANNEL_ID})" | tee -a "$ANALYSIS_LOG"
  
  # FAQ 파일 초기화 (없으면 생성)
  if [ ! -f "$FAQ_FILE" ]; then
    echo '{"channel": "'$channel_name'", "faqs": []}' > "$FAQ_FILE"
  fi
  
  # 최근 7일간 메시지 검색 (OpenClaw message search 사용)
  # 주의: 실제 검색 명령어는 구현에 따라 다를 수 있음
  SEARCH_RESULT=$(openclaw message search \
    --channel discord \
    --channel-id "$CHANNEL_ID" \
    --query "*" \
    --limit 500 2>/dev/null || echo "{}")
  
  # Node.js로 질문 패턴 분석
  CHANNEL_NAME="$channel_name" FAQ_FILE="$FAQ_FILE" SEARCH_RESULT="$SEARCH_RESULT" node <<'EOFJS'
const fs = require('fs');
const channelName = process.env.CHANNEL_NAME || 'unknown';
const faqFile = process.env.FAQ_FILE || '';
const searchResult = JSON.parse(process.env.SEARCH_RESULT || "{}");

// 기존 FAQ 로드
const existingFaq = JSON.parse(fs.readFileSync(faqFile, 'utf8'));

// 질문 추출 (? 로 끝나는 메시지)
const questions = (searchResult.messages || [])
  .filter(msg => msg.content && msg.content.includes('?'))
  .map(msg => ({
    content: msg.content.trim(),
    author: msg.author,
    timestamp: msg.timestamp
  }));

// 질문 빈도 계산 (단순 문자열 매칭)
const questionFreq = {};
questions.forEach(q => {
  const normalized = q.content.toLowerCase().replace(/\s+/g, ' ');
  if (!questionFreq[normalized]) {
    questionFreq[normalized] = {
      count: 0,
      examples: []
    };
  }
  questionFreq[normalized].count++;
  if (questionFreq[normalized].examples.length < 3) {
    questionFreq[normalized].examples.push(q);
  }
});

// 3회 이상 반복된 질문 추출
const frequentQuestions = Object.entries(questionFreq)
  .filter(([q, data]) => data.count >= 3)
  .sort((a, b) => b[1].count - a[1].count);

if (frequentQuestions.length > 0) {
  console.log(`발견: ${frequentQuestions.length}개의 반복 질문 (3회+)`);
  
  // 신규 FAQ 후보 추출
  const newFaqs = frequentQuestions.map(([question, data]) => ({
    question: question,
    frequency: data.count,
    examples: data.examples.map(e => e.timestamp),
    answer: null, // 수동으로 작성 필요
    auto_detected: true,
    detected_at: new Date().toISOString()
  }));
  
  // 기존 FAQ와 병합 (중복 제거)
  const existingQuestions = new Set(
    existingFaq.faqs.map(f => f.question.toLowerCase())
  );
  
  const trulyNew = newFaqs.filter(f =>
    !existingQuestions.has(f.question.toLowerCase())
  );
  
  if (trulyNew.length > 0) {
    existingFaq.faqs.push(...trulyNew);
    existingFaq.last_updated = new Date().toISOString();
    fs.writeFileSync(faqFile, JSON.stringify(existingFaq, null, 2));
    console.log(`✅ ${trulyNew.length}개의 신규 FAQ 후보 등록`);
  } else {
    console.log("ℹ️ 모든 반복 질문이 이미 FAQ에 등록됨");
  }
} else {
  console.log("ℹ️ 반복 질문 없음 (모두 3회 미만)");
}
EOFJS

done

# Discord 알림 (#jarvis-system)
NEW_FAQS_COUNT=$(find "$FAQ_DIR" -name "faq-*.json" -exec jq '[.faqs[] | select(.auto_detected == true and .answer == null)] | length' {} \; | awk '{s+=$1} END {print s}')

if [ "$NEW_FAQS_COUNT" -gt 0 ]; then
  MESSAGE="📚 **FAQ 학습 완료**

날짜: $(date '+%Y-%m-%d %H:%M:%S')
신규 FAQ 후보: ${NEW_FAQS_COUNT}개

**다음 조치:**
1. \`~/openclaw/memory/faq/faq-*.json\` 파일 확인
2. \`answer\` 필드를 채워서 FAQ 완성
3. 완성된 FAQ는 자동으로 응답에 활용됨

**위치:** \`~/openclaw/memory/faq/\`"

  openclaw message send \
    --channel discord \
    --target 1469190688083280065 \
    --message "$MESSAGE" 2>&1 | tee -a "$ANALYSIS_LOG" || true
fi

echo "✅ FAQ 학습 완료. 신규 후보: ${NEW_FAQS_COUNT:-0}개"
