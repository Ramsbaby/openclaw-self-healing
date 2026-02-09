#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const JOBS_FILE = path.join(process.env.HOME, '.openclaw/cron/jobs.json');

// Option A (보수적): 테이블 빈 줄 + 이모지 축소 + ANSI 제거
const TQQQ_FIXED = `# 📊 TQQQ Live Monitor

-# Yahoo Finance 15분 지연 | 환율: 실시간 API

**보유 포지션:**
- 평균 매수가: $52.26 (₩76,033/주)
- 수량: 47주
- 총 투자금: ₩3,573,560

---

**Task:**

1. **현재 시세 조회:**
   \`\`\`bash
   ~/openclaw/skills/yahoo-finance/yf TQQQ
   \`\`\`

2. **손익 계산 (2단계):**
   
   **A. 달러 기준:**
   - 현재가: $XX.XX
   - 매수가: $52.26
   - 손익: $X.XX (±X.XX%)
   
   **B. 원화 환산:**
   - 환율: ₩X,XXX (매수시: ₩1,455)
   - 환율 변동: ±X.XX%
   - 평가금액: ₩X,XXX,XXX
   - 손익: ₩XXX,XXX (±X.XX%)

3. **전략 라인 (매수가 $52.26 기준):**
   - 손절: $48.60 (-7%)
   - 추가매수: $50.69 (-3%)
   - 익절: $53.83 (+3%)

---

**출력 형식:**

## 업데이트 시각

현재 시각 텍스트 (예: 2026.02.04 16:15 KST)

## 손익 요약

| 구분        | 달러      | 원화         |
|------------|----------|-------------|
| 현재가      | $XX.XX   | ₩XX,XXX     |
| 매수가      | $52.26   | ₩76,033     |
| 손익(달러)  | $X.XX    | ±X.XX%      |
| 손익(원화)  | ₩XXX,XXX | ±X.XX%      |

**환율 영향:** USD/KRW ₩X,XXX (변동: ±X.XX%)

**전략:** HOLD / 추가매수 / 익절 / 손절
**근거:** [1-2줄]

---

**자기평가:**

>>> ✅/⚠️ 완성도: [X/5]
✅/⚠️ 정확성: [OK/WARNING]
✅/⚠️ 톤: [Jarvis/ChatGPT]
✅/⚠️ 간결성: [X emojis]
✅/⚠️ 가독성: [헤더/테이블]
💡 개선: [액션]`;

const MORNING_FIXED = `# ☀️ Good Morning, Sir.

-# 2026.MM.DD (요일) | Seoul, South Korea

## 환율

USD/KRW: ₩X,XXX.XX (전일 대비: ±X.XX%)

\`\`\`bash
python3 ~/openclaw/scripts/get-exchange-rate.py
\`\`\`

---

## 포트폴리오

| 종목 | 현재가  | 변동  |
|------|---------|-------|
| TQQQ | $XX.XX  | ±X.X% |
| SOXL | $XX.XX  | ±X.X% |
| NVDA | $XX.XX  | ±X.X% |

\`\`\`bash
~/openclaw/skills/yahoo-finance/yf TQQQ
~/openclaw/skills/yahoo-finance/yf SOXL
~/openclaw/skills/yahoo-finance/yf NVDA
\`\`\`

---

## Hot Scanner

상위 3개:

1. [종목] - [이유]
2. [종목] - [이유]
3. [종목] - [이유]

\`\`\`bash
python3 ~/openclaw/skills/stock-analysis/scripts/hot_scanner.py --no-social
\`\`\`

---

## Rumor Scanner

Impact 7점 이상:

> **[제목]** (Impact: X.X/10)
> 출처: [소스]

\`\`\`bash
python3 ~/openclaw/skills/stock-analysis/scripts/rumor_scanner.py
\`\`\`

---

## 오늘의 전략

[Hot + Rumor 종합]

---

**자기평가:**

>>> ✅/⚠️ 완성도: [X/6]
✅/⚠️ 정확성: [OK/WARNING]
✅/⚠️ 톤: [Jarvis/ChatGPT]
✅/⚠️ 간결성: [X emojis]
✅/⚠️ 가독성: [헤더/테이블]
💡 개선: [액션]`;

const WRAPUP_FIXED = `# 🌆 퇴근 브리핑

-# 2026.MM.DD HH:MM KST

## 귀가 정보

**날씨:** 우산/외투 필요 여부 (현재 X°C → 저녁 Y°C)

**교통:** 최적 경로 및 소요 시간

**내일 일정:** 미리 보기

---

## 시스템 상태

| 항목   | 사용량            | 상태 |
|--------|------------------|------|
| CPU    | user X% / sys Y% | ✅   |
| Memory | XX.XG / YY.YG    | ✅   |
| Disk   | XXGi / YYGi (Z%) | ✅   |

\`\`\`bash
top -l 1 | grep "CPU usage"
top -l 1 | grep PhysMem
df -h ~ | tail -1
\`\`\`

---

## Claude 사용량

> 세션 X% 사용 (Y% 남음)

\`\`\`bash
claude (PTY) → /usage
\`\`\`

누적 비용: $XX.XX

---

**자기평가:**

>>> ✅/⚠️ 완성도: [X/4]
✅/⚠️ 정확성: [OK/WARNING]
✅/⚠️ 톤: [Jarvis/ChatGPT]
✅/⚠️ 간결성: [X emojis]
✅/⚠️ 가독성: [헤더/테이블]
💡 개선: [액션]`;

const FIXES = {
  'a98f06f7-a084-4993-b352-358d00ed340f': {
    name: 'TQQQ 15분 모니터링',
    message: TQQQ_FIXED
  },
  'b9662f08-36ee-4e6d-ab9d-fd2d48f21737': {
    name: '모닝 브리핑',
    message: MORNING_FIXED
  },
  'bd8e8994-3646-4f7a-b994-4f3ae9f1890a': {
    name: 'Daily Wrap-up',
    message: WRAPUP_FIXED
  }
};

try {
  const data = JSON.parse(fs.readFileSync(JOBS_FILE, 'utf8'));
  
  let updated = 0;
  
  data.jobs.forEach(job => {
    const fix = FIXES[job.id];
    if (!fix) return;
    
    job.payload.message = fix.message;
    job.updatedAtMs = Date.now();
    updated++;
    console.log(`[FIX] ${fix.name}`);
  });
  
  fs.writeFileSync(JOBS_FILE, JSON.stringify(data, null, 2));
  console.log(`\n✅ ${updated}개 크론 수정 완료 (Option A)`);
  console.log('변경사항:');
  console.log('- 테이블 앞뒤 빈 줄 추가');
  console.log('- 이모지 2~3개로 축소');
  console.log('- 타임스탬프 → 날짜 텍스트');
  console.log('- ANSI 컬러 제거');
  
} catch (error) {
  console.error('❌ 에러:', error.message);
  process.exit(1);
}
