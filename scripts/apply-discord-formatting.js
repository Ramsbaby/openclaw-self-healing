#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const JOBS_FILE = path.join(process.env.HOME, '.openclaw/cron/jobs.json');

// TQQQ 15분 모니터링 - 풀 리포맷
const TQQQ_MESSAGE = `# 📊 TQQQ Live Monitor

-# Yahoo Finance 15분 지연 | 환율: 실시간 API

**보유 포지션:**
- 평균 매수가: $52.26 (₩76,033/주)
- 수량: 47주
- 총 투자금: ₩3,573,560
- 추가 투자 가능: ₩6,439,670

---

**Task:**

1. **현재 시세 조회:**
   \`\`\`bash
   ~/openclaw/skills/yahoo-finance/yf TQQQ
   \`\`\`

2. **손익 계산 (2단계 분리):**
   
   **A. 달러 기준 (순수 주가 변동):**
   - 현재가: $XX.XX
   - 매수가: $52.26
   - 달러 손익: $X.XX (±X.XX%)
   - 달러 평가금액: $X,XXX.XX
   
   **B. 원화 환산 (환율 영향 포함):**
   - 현재 환율: ₩X,XXX.XX (매수 당시: ₩1,455.10)
   - 환율 변동: ±X.XX%
   - 원화 평가금액: ₩X,XXX,XXX
   - 원화 손익: ₩XXX,XXX (±X.XX%)

3. **전략 라인 (매수가 $52.26 기준):**
   - 🔴 손절가: $48.60 (-7%) → ₩70,711
   - 🟡 추가매수: $50.69 (-3%) → ₩73,752, 250만원 투입
   - 🟢 익절가: $53.83 (+3%) → ₩78,314, 23~24주 매도

---

**출력 형식 (Discord 최적화):**

## 🕐 XX:XX 업데이트

| 구분           | 달러        | 원화          |
|---------------|------------|---------------|
| 현재가         | $XX.XX     | ₩XX,XXX       |
| 매수가         | $52.26     | ₩76,033       |
| 손익 (달러)    | $X.XX      | ±X.XX%        |
| 손익 (원화)    | ₩XXX,XXX   | ±X.XX%        |
| 일중 범위      | -          | ₩XX,XXX ~ XX,XXX |

**💱 환율 영향:**
- USD/KRW: ₩X,XXX (매수시: ₩1,455)
- 환율 변동: ±X.XX%

**📊 전략 판단:**

\`\`\`ansi
[HOLD/추가매수/익절/손절 중 하나를 선택하고 ANSI 컬러 적용]
✅ = \\u001b[1;32m전략: HOLD\\u001b[0m
⚠️ = \\u001b[1;33m전략: 추가매수 검토\\u001b[0m
🔴 = \\u001b[1;31m전략: 손절 고려\\u001b[0m
🟢 = \\u001b[1;32m전략: 익절 타이밍\\u001b[0m
\`\`\`

근거: [기술적 분석 1-2줄]

---

**📊 자기평가 (아래 형식으로 반드시 출력):**

>>> ✅/⚠️ 완성도: [X/5] (누락: XXX)
✅/⚠️ 정확성: [OK/WARNING: XXX]
✅/⚠️ 톤: [Jarvis/ChatGPT-like]
✅/⚠️ 간결성: [X emojis, Y lines]
✅/⚠️ 가독성: [Discord 포맷 활용도]
💡 개선: [구체적 액션]`;

// 모닝 브리핑
const MORNING_MESSAGE = `# ☀️ Good Morning, Sir.

-# <t:TIMESTAMP:F> | Seoul, South Korea

## 💱 환율 (USD/KRW)

실시간 환율:
\`\`\`bash
python3 ~/openclaw/scripts/get-exchange-rate.py
\`\`\`
→ ₩X,XXX.XX (전일 대비: ±X.XX원, ±X.XX%)

---

## 📈 포트폴리오 브리핑

| 종목  | 현재가  | 변동   | 평가액        |
|-------|---------|--------|---------------|
| TQQQ  | $XX.XX  | ±X.X%  | ₩X,XXX,XXX    |
| SOXL  | $XX.XX  | ±X.X%  | ₩X,XXX,XXX    |
| NVDA  | $XX.XX  | ±X.X%  | ₩X,XXX,XXX    |

\`\`\`bash
~/openclaw/skills/yahoo-finance/yf TQQQ
~/openclaw/skills/yahoo-finance/yf SOXL
~/openclaw/skills/yahoo-finance/yf NVDA
\`\`\`

---

## 🔥 Hot Scanner (트렌딩 종목)

\`\`\`bash
python3 ~/openclaw/skills/stock-analysis/scripts/hot_scanner.py --no-social
\`\`\`

**상위 3개만 간단히:**
1. [종목명] - [이유]
2. [종목명] - [이유]
3. [종목명] - [이유]

---

## 🔮 Rumor Scanner (조기 시그널)

\`\`\`bash
python3 ~/openclaw/skills/stock-analysis/scripts/rumor_scanner.py
\`\`\`

**Impact 7점 이상만:**

> 🔮 **[루머 제목]** (Impact: X.X/10)
> 출처: [소스]
> 영향: [M&A/내부자거래/업그레이드 등]

---

## 💡 오늘의 전략

Hot + Rumor 종합 분석 → 액션 아이템

---

**📊 자기평가 (아래 형식으로 반드시 출력):**

>>> ✅/⚠️ 완성도: [X/6] (환율/시세/Hot/Rumor/전략/평가)
✅/⚠️ 정확성: [OK/WARNING: XXX]
✅/⚠️ 톤: [Jarvis/ChatGPT-like]
✅/⚠️ 간결성: [X emojis, Y lines]
✅/⚠️ 가독성: [헤더/테이블/컬러 활용]
💡 개선: [구체적 액션]

-# TIMESTAMP는 실행 시각의 유닉스 타임스탬프로 교체`;

// Daily Wrap-up
const WRAPUP_MESSAGE = `# 🌆 퇴근 브리핑

-# <t:TIMESTAMP:F>

## 🌤️ 귀가 정보

**날씨:** 귀가길 우산/외투 필요 여부
- 현재 기온: XX°C
- 저녁 예상: XX°C

**교통:** 최적 경로 및 소요 시간

**내일 일정:** 미리 보는 스케줄

---

## 💻 시스템 사용량

**Mac mini 상태:**

| 항목   | 사용량               | 상태 |
|--------|---------------------|------|
| CPU    | user X% / sys Y%    | ✅   |
| Memory | XX.XG / YY.YG (Z%)  | ✅   |
| Disk   | XXGi / YYGi (Z%)    | ✅   |

\`\`\`bash
top -l 1 | grep "CPU usage"
top -l 1 | grep PhysMem
df -h ~ | tail -1
\`\`\`

---

**Claude 사용량:**

\`\`\`bash
claude (PTY) → /usage
\`\`\`

> 💡 **남은 사용량:** 세션 X% 사용 (Y% 남음)

누적 비용: $XX.XX (참고)

---

**📊 자기평가 (아래 형식으로 반드시 출력):**

>>> ✅/⚠️ 완성도: [X/4] (날씨/시스템/Claude/평가)
✅/⚠️ 정확성: [OK/WARNING: XXX]
✅/⚠️ 톤: [Jarvis/ChatGPT-like]
✅/⚠️ 간결성: [X emojis, Y lines]
✅/⚠️ 가독성: [헤더/테이블 활용]
💡 개선: [구체적 액션]`;

const CRON_UPDATES = {
  'a98f06f7-a084-4993-b352-358d00ed340f': {
    name: 'TQQQ 15분 모니터링',
    message: TQQQ_MESSAGE
  },
  'b9662f08-36ee-4e6d-ab9d-fd2d48f21737': {
    name: '모닝 브리핑',
    message: MORNING_MESSAGE
  },
  'bd8e8994-3646-4f7a-b994-4f3ae9f1890a': {
    name: 'Daily Wrap-up',
    message: WRAPUP_MESSAGE
  }
};

try {
  const data = JSON.parse(fs.readFileSync(JOBS_FILE, 'utf8'));
  
  let updated = 0;
  
  data.jobs.forEach(job => {
    const config = CRON_UPDATES[job.id];
    if (!config) return;
    
    job.payload.message = config.message;
    job.updatedAtMs = Date.now();
    updated++;
    console.log(`[UPDATE] ${config.name}`);
  });
  
  fs.writeFileSync(JOBS_FILE, JSON.stringify(data, null, 2));
  console.log(`\n✅ ${updated}개 크론 Discord 포맷팅 적용 완료`);
  
} catch (error) {
  console.error('❌ 에러:', error.message);
  process.exit(1);
}
