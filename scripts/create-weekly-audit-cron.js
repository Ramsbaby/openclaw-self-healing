#!/usr/bin/env node
/**
 * Create weekly audit cron for self-evaluation system
 * 
 * Runs every Sunday night at 23:30
 * Analyzes all validation results from the past week
 * Generates comprehensive report with recommendations
 */

const { execSync } = require('child_process');

function createWeeklyAuditCron() {
  const job = {
    name: '🔬 Weekly Self-Evaluation Audit',
    enabled: true,
    schedule: {
      kind: 'cron',
      expr: '30 23 * * 0',  // Sunday 23:30
      tz: 'Asia/Seoul'
    },
    sessionTarget: 'isolated',
    wakeMode: 'next-heartbeat',
    payload: {
      kind: 'agentTurn',
      model: 'anthropic/claude-opus-4-5',
      thinking: 'high',
      channel: 'discord',
      to: 'channel:1468386844621144065',
      deliver: true,
      message: `
🔬 **주간 자기평가 감사 (Weekly Self-Evaluation Audit)**

**Mission:** 지난 7일간 자기평가 시스템 전체를 심층 분석하고 개선 방향 제시

---

## Phase 1: Data Collection

1. **Validation 결과 수집:**
   \`\`\`bash
   for i in {0..6}; do
     date=$(date -v-$i'd' '+%Y-%m-%d')
     if [ -f ~/openclaw/memory/validation-$date.jsonl ]; then
       echo "Found: validation-$date.jsonl"
       cat ~/openclaw/memory/validation-$date.jsonl
     fi
   done
   \`\`\`

2. **Self-Review 기록 수집 (있으면):**
   \`\`\`bash
   for i in {0..6}; do
     date=$(date -v-$i'd' '+%Y-%m-%d')
     if [ -f ~/openclaw/memory/self-review-$date.md ]; then
       echo "Found: self-review-$date.md"
       cat ~/openclaw/memory/self-review-$date.md
     fi
   done
   \`\`\`

3. **Daily 메모리 스캔:**
   \`\`\`bash
   for i in {0..6}; do
     date=$(date -v-$i'd' '+%Y-%m-%d')
     if [ -f ~/openclaw/memory/$date.md ]; then
       # Extract sections mentioning "자기평가", "평가", "reflection"
       grep -A 5 -B 5 -i "자기평가\\|평가\\|reflection" ~/openclaw/memory/$date.md || true
     fi
   done
   \`\`\`

---

## Phase 2: Statistical Analysis

수집한 JSONL 데이터를 분석하여 다음 통계 산출:

### 2.1 전체 통계
- **총 크론 실행:** ? 회
- **자기평가 수행:** ? 회 (수행률: ?%)
- **Validation 통과:** ? 회 (통과율: ?%)
- **Validation 실패:** ? 회 (실패율: ?%)

### 2.2 Verdict 분포
- **PASS:** ? 회 (?%)
- **WARN:** ? 회 (?%)
- **INFO:** ? 회 (?%)
- **FAIL:** ? 회 (?%)

### 2.3 실패 원인 분석

각 validationFlags의 type별 집계:

| Flag Type | Count | % | Severity Distribution |
|-----------|-------|---|----------------------|
| INACCURATE_SELF_EVALUATION | ? | ?% | HIGH: ?, MEDIUM: ?, LOW: ? |
| FORBIDDEN_PHRASE | ? | ?% | HIGH: ?, MEDIUM: ?, LOW: ? |
| EMOJI_OVERFLOW | ? | ?% | HIGH: ?, MEDIUM: ?, LOW: ? |
| SEPARATOR_OVERFLOW | ? | ?% | HIGH: ?, MEDIUM: ?, LOW: ? |
| TONE_MISMATCH | ? | ?% | HIGH: ?, MEDIUM: ?, LOW: ? |
| HIGH_ERROR_RATE | ? | ?% | HIGH: ?, MEDIUM: ?, LOW: ? |
| PERFORMANCE_DEGRADATION | ? | ?% | HIGH: ?, MEDIUM: ?, LOW: ? |
| ... | ... | ... | ... |

### 2.4 크론별 성적표

각 크론의 통과율:

| Cron Name | Executions | PASS | WARN | INFO | FAIL | Pass Rate |
|-----------|-----------|------|------|------|------|-----------|
| TQQQ 15분 모니터링 | ? | ? | ? | ? | ? | ?% |
| Daily Stock Briefing | ? | ? | ? | ? | ? | ?% |
| Trend Hunter | ? | ? | ? | ? | ? | ?% |
| ... | ... | ... | ... | ... | ... | ... |

---

## Phase 3: Pattern Analysis (Deep Thinking)

### 3.1 반복 패턴 발견

**자문:**
- 특정 크론이 계속 같은 실수를 반복하는가?
- 특정 시간대에 품질이 떨어지는가? (피로도 영향?)
- 특정 유형의 작업에서 자기평가가 부정확한가?
- 개선 제안이 실제로 반영되는가? (Week 1 제안 → Week 2 개선 여부)

**예시:**
- "TQQQ 크론은 7회 중 5회가 TONE_MISMATCH → 금지 표현을 계속 사용"
- "저녁 크론들(19:00~23:00)은 통과율 62%, 아침 크론들(06:00~09:00)은 통과율 91% → 피로도 영향?"
- "Trend Hunter는 INACCURATE_SELF_EVALUATION 3회 → 복잡한 작업에서 자기평가 어려움"

### 3.2 자기평가 신뢰도 측정

**Accuracy Score 계산:**
- Self-reported "OK" but validation found errors: -1 point
- Self-reported "Jarvis" but forbidden phrases: -1 point
- Self-reported emoji count ≠ actual: -0.5 point
- Accurate self-evaluation: +1 point

각 크론의 평균 Accuracy Score:
- Score > 0.8: 신뢰도 높음 (자기평가 정확)
- Score 0.5~0.8: 보통 (가끔 부정확)
- Score < 0.5: 신뢰도 낮음 (자기평가 불신)

### 3.3 개선 트렌드 분석

**Week-over-Week 비교:**
- 이번 주 통과율 vs 지난 주 통과율
- 개선된 크론, 악화된 크론
- 새로 발생한 문제, 해결된 문제

---

## Phase 4: Root Cause Analysis

실패 사례 Deep Dive (상위 3개):

**예시 분석:**

### Case 1: TQQQ 크론 - TONE_MISMATCH (5회 반복)

**증거:**
- 2026-02-01: "변동 감지했습니다" (forbidden)
- 2026-02-03: "확인했습니다" (forbidden)
- 2026-02-04: "알겠습니다" (forbidden)
- ...

**Self-Evaluation:**
- 모두 "✅ 톤: Jarvis"라고 자기평가 → 부정확

**Root Cause:**
- Response Guard 규칙을 알고 있으나 실제 응답 작성 시 습관적으로 ChatGPT 톤 사용
- Pre-Flight Checklist를 건너뜀 (체크박스가 의미 없음)
- 자기평가 시점에 이미 금지 표현 사용한 것을 잊어버림

**Why it persists:**
- Reflection에서 "다음엔 체크" 제안했으나 실제로 안 함
- Feedback loop 부재 (이전 실패를 다음 실행 시 상기시키지 않음)

**Recommended Fix:**
- 응답 작성 전 Response Guard 재주입 (프롬프트에 금지 표현 리스트 포함)
- 또는 응답 작성 후 자동 스캔 → 금지 표현 발견 시 재작성 강제

---

## Phase 5: Recommendations

### 5.1 즉시 조치 (Critical)

1. **자기평가 기준 명확화**
   - [ ] "OK"의 정의 문서화: 0 tool errors, 0 data inaccuracies
   - [ ] "Jarvis"의 정의 문서화: 0 forbidden phrases, witty opening
   - [ ] AGENTS.md에 체크리스트 구체화

2. **Evaluation 전 체크리스트 강제 실행**
   - [ ] Pre-Flight Checklist를 의무화
   - [ ] 금지 표현 스캔 자동화 (스크립트)
   - [ ] 포맷 카운트 자동 제공 (이모지, 구분선)

3. **Feedback Loop 구현**
   - [ ] Validation 실패 시 다음 크론에 경고 주입
   - [ ] "지난번 당신은 X를 놓쳤습니다. 이번엔 체크하세요."

### 5.2 중기 조치 (Important)

4. **Reflection 품질 개선**
   - [ ] "왜 이렇게 평가했나?" 질문 추가
   - [ ] 평가 근거 명시 (예: "OK - yf 스크립트 exit 0")
   - [ ] Root cause analysis 심화

5. **Baseline 정확도 향상**
   - [ ] Baseline 데이터 30개 샘플 축적 (현재: ?개)
   - [ ] Metric thresholds 조정 (false positive 줄이기)

### 5.3 장기 조치 (Nice to Have)

6. **LLM-as-Judge (Opus 모델로 일부 재평가)**
   - [ ] 주간 감사 시 Validation FAIL 건 중 10개 샘플링
   - [ ] Opus 모델로 재평가 (Haiku 자기평가 vs Opus 평가 비교)
   - [ ] 정확도 측정

7. **Human-in-the-Loop (월 1회 정우님 리뷰)**
   - [ ] 월말에 한 달치 감사 보고서 생성
   - [ ] 정우님께 top 5 문제 케이스 제출
   - [ ] 피드백 반영

---

## Phase 6: Report Generation

### Executive Summary

**주간 성적: [A/B/C/D/F]**
- 통과율: ?% (목표: 90%)
- 개선 트렌드: [↑ 상승 / → 정체 / ↓ 하락]
- 주요 문제: [Top 3 flags]

**핵심 발견:**
1. [가장 중요한 패턴 1개]
2. [두 번째 중요한 패턴]
3. [세 번째 중요한 패턴]

**권장 조치:**
1. [즉시 조치 1개] (예상 효과: ?% 개선)
2. [중기 조치 1개] (예상 효과: ?% 개선)

**다음 주 목표:**
- 통과율 ?% → ?% 달성
- [특정 크론] 개선 집중

---

### 상세 데이터

(위에서 산출한 통계 표 전부 첨부)

---

## Final Output

위 분석을 모두 수행한 후, 다음 형식으로 보고:

\`\`\`
🔬 **주간 자기평가 감사 보고서**
📅 2026-02-01 ~ 2026-02-07

[Executive Summary]

[상세 통계]

[패턴 분석]

[Root Cause 사례]

[권장 조치]
\`\`\`

**중요:** 
- Opus + Thinking High로 심층 분석
- 표면적 숫자가 아닌 근본 원인 파악
- 실행 가능한 구체적 조치 제시
- 다음 주 개선 목표 명확히 설정
      `.trim()
    }
  };
  
  return job;
}

async function main() {
  console.log('🔬 Creating weekly self-evaluation audit cron...\n');
  
  try {
    const job = createWeeklyAuditCron();
    const jobJson = JSON.stringify(job).replace(/'/g, "\\'");
    const cmd = `openclaw cron add '${jobJson}'`;
    
    const result = execSync(cmd, { encoding: 'utf8' });
    console.log(`✅ Created weekly audit cron`);
    console.log(`   Schedule: ${job.schedule.expr} (Every Sunday 23:30 KST)`);
    console.log(`   Model: ${job.payload.model} (Opus + Thinking High)`);
    console.log(`\n📊 This cron will:`);
    console.log(`   1. Analyze all validation results from past 7 days`);
    console.log(`   2. Identify patterns and root causes`);
    console.log(`   3. Calculate accuracy scores per cron`);
    console.log(`   4. Generate comprehensive report with recommendations`);
    console.log(`   5. Set goals for next week`);
    console.log(`\n✨ First run: Next Sunday at 23:30`);
  } catch (e) {
    if (e.message.includes('already exists')) {
      console.log(`⏭️  Skipped: Weekly audit cron already exists`);
    } else {
      console.log(`❌ Failed to create weekly audit cron:`);
      console.log(`   Error: ${e.message}`);
      throw e;
    }
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { createWeeklyAuditCron };
