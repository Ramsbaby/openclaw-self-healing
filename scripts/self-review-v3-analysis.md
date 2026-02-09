# 자기평가 시스템 V3 - 이중삼중 검증 프레임워크

## 문제 진단 (V2의 한계)

### 현재 V2 시스템
```markdown
✅/⚠️ 완성도: [X/Y]
✅/⚠️ 정확성: [OK/WARNING]
✅/⚠️ 톤: [Jarvis/ChatGPT]
✅/⚠️ 간결성: [X emojis]
💡 개선: [구체적 액션]
```

### V2의 근본적 문제

**1. 자기평가의 편향 (Self-Evaluation Bias)**
- AI가 자신의 출력을 평가하는 것은 근본적으로 편향됨
- "내가 잘했다"고 생각하면 실제로 문제가 있어도 OK 판정
- 주관적 기준(톤, 간결성)은 일관성 없이 평가됨

**2. 검증 메커니즘 부재**
- 평가 결과를 검증하는 외부 시스템 없음
- 잘못된 평가를 감지할 방법 없음
- 평가 자체가 틀렸는지 알 수 없음

**3. 객관적 지표 부족**
- "완성도 X/Y"가 무엇인지 모호
- "정확성 OK"의 기준 불명확
- 측정 가능한 메트릭 없음

**4. 학습 루프 부재**
- 평가 결과가 다음 실행에 반영 안 됨
- 같은 실수 반복 가능
- 개선 방향 제시만 하고 실제 개선은 안 됨

---

## 업계 베스트 프랙티스 (2025 최신)

### 1. 이중 검증 시스템 (Dual Validation)

**출처:** Medium (Dec 2025), "AI agent evaluate another AI agent"

**방식:**
```
1차: Self-Evaluation (자기평가)
   ↓
2차: External Validation (외부 검증 - 다른 AI 또는 규칙 기반)
   ↓
3차: Audit (감사 - 인간 또는 더 강력한 모델)
```

**예시:**
- Haiku 모델이 크론 실행 → 자기평가
- Sonnet 모델이 평가 결과 재검증
- 불일치 시 정우님께 보고

### 2. 객관적 메트릭 측정

**출처:** WEF 2025 AI Agents Framework, Galileo AI

**측정 항목:**
- **Task Success Rate:** 요청된 작업을 완수했는가?
- **Completion Time:** 예상 시간 내 완료했는가?
- **Error Frequency:** 도구 호출 실패, API 에러 발생 횟수
- **Token Efficiency:** 불필요한 토큰 낭비 없는가?
- **Baseline Error Rate:** 과거 평균 대비 현재 성능

**구체적 지표 예시:**
```json
{
  "taskSuccess": true,
  "completionTimeMs": 3427,
  "expectedTimeMs": 5000,
  "toolCallErrors": 0,
  "tokenUsage": 2847,
  "baselineTokenAvg": 3200,
  "errorRate": 0.0,
  "baselineErrorRate": 0.02
}
```

### 3. 다기준 평가 (Multi-Criteria)

**출처:** EMNLP 2025 ReviewEval, Medium AI Agent Evaluation

**4대 축:**
1. **Accuracy (정확성):** 사실 확인, 데이터 검증
2. **Completeness (완성도):** 요구사항 모두 충족했는가
3. **Relevance (관련성):** 맥락에 맞는 응답인가
4. **Quality (품질):** 톤, 스타일, 포맷팅

**각 축을 1-5 점수로 정량화:**
```
Accuracy: 5/5 (모든 데이터 검증됨)
Completeness: 4/5 (2/3 요구사항만 충족)
Relevance: 5/5 (맥락 완벽)
Quality: 3/5 (톤이 ChatGPT 같음)
```

### 4. Reflection 메커니즘

**출처:** Anthropic Research (Bloom), OpenAI Cookbook

**CoT (Chain of Thought) Reflection:**
```
1. 실행 (Do)
2. 자기평가 (Self-Evaluate)
3. 반성 (Reflect): "왜 이렇게 했나? 더 나은 방법은?"
4. 계획 (Plan Next): "다음엔 이렇게 개선"
```

**예시:**
```markdown
## Reflection
**What I did:** TQQQ 시세 체크 후 -4.5% 보고
**What went well:** 정확한 데이터, 빠른 응답
**What went wrong:** 환율 영향 설명 누락
**Why:** 스크립트가 환율 데이터 미포함
**Next time:** get-exchange-rate.py 통합 확인
```

### 5. Red Teaming & Continuous Monitoring

**출처:** Microsoft Azure Agent Factory, PwC Multi-Agent Validation

**사전 검증 (Pre-deployment):**
- Adversarial inputs 테스트
- Edge case 시뮬레이션
- Worst-case scenario 검증

**실시간 모니터링 (Post-deployment):**
- Drift detection (성능 저하 감지)
- Anomaly detection (비정상 행동 감지)
- Compliance monitoring (정책 위반 감지)

---

## V3 설계안: 3단계 검증 프레임워크

### Architecture

```
┌─────────────────────────────────────────────────┐
│ Stage 1: Execution + Self-Evaluation (Haiku)   │
│  - 크론 실행                                      │
│  - 즉시 자기평가 (V2 형식 유지)                   │
│  - 객관적 메트릭 수집                             │
└──────────────┬──────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────┐
│ Stage 2: External Validation (Rule-Based)       │
│  - 메트릭 검증 (threshold 체크)                   │
│  - 포맷 검증 (이모지/구분선/헤더 카운트)           │
│  - 일관성 검증 (과거 평가와 비교)                  │
└──────────────┬──────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────┐
│ Stage 3: Periodic Audit (Weekly, Sonnet)        │
│  - 주간 평가 리뷰 (100개 평가 재검증)             │
│  - 패턴 분석 (반복 실수, 개선 트렌드)             │
│  - 보고서 생성 (정우님께 전달)                    │
└─────────────────────────────────────────────────┘
```

### Stage 1: Execution + Self-Evaluation

**크론 실행 직후 (Haiku 모델):**

```markdown
## 자기평가 (V2 유지)

✅ 완성도: 3/3 (TQQQ 시세, 환율, 변동률 모두 포함)
✅ 정확성: OK (Yahoo Finance 15분 지연 데이터)
⚠️ 톤: ChatGPT-like ("변동 감지했습니다" - 로봇 톤)
✅ 간결성: 2 emojis, 적절
💡 개선: "감지했습니다" → "보고합니다" 또는 "-4.5% 낙하 중"

## 객관적 메트릭

- Task Success: ✅ (모든 도구 호출 성공)
- Completion Time: 3.2s (baseline 4.1s 대비 빠름)
- Tool Errors: 0
- Token Usage: 847 (baseline 920)
- Format Violations: 1 (forbidden phrase detected)
```

### Stage 2: External Validation (Rule-Based)

**크론 완료 1분 후 (자동 스크립트):**

```javascript
// scripts/validate-self-review.js
const evaluation = parseSelfReview(cronOutput);

// 1. 메트릭 검증
if (evaluation.toolErrors > 2) {
  flag("HIGH_ERROR_RATE");
}
if (evaluation.completionTime > evaluation.baseline * 1.5) {
  flag("PERFORMANCE_DEGRADATION");
}

// 2. 포맷 검증
const formatViolations = detectFormatViolations(cronOutput);
if (formatViolations.length !== evaluation.formatViolations) {
  flag("INACCURATE_SELF_EVALUATION", {
    selfReported: evaluation.formatViolations,
    actual: formatViolations.length
  });
}

// 3. 일관성 검증
const recentEvals = loadRecentEvaluations(7); // 최근 7일
if (evaluation.tone === "Jarvis" && recentEvals.filter(e => e.tone === "ChatGPT").length > 5) {
  flag("INCONSISTENT_TONE_EVALUATION", "Self-reported Jarvis but recent history shows ChatGPT pattern");
}

// 4. 결과 기록
logValidationResult({
  cronId: cronId,
  timestamp: Date.now(),
  selfEvaluation: evaluation,
  validationFlags: flags,
  verdict: flags.length === 0 ? "PASS" : "FAIL"
});
```

**검증 결과 예시:**

```json
{
  "cronId": "a98f06f7-...",
  "timestamp": 1738652420000,
  "selfEvaluation": {
    "completeness": "3/3",
    "accuracy": "OK",
    "tone": "ChatGPT-like",
    "conciseness": "2 emojis"
  },
  "validationFlags": [
    {
      "type": "INACCURATE_SELF_EVALUATION",
      "severity": "MEDIUM",
      "detail": "Self-reported 1 format violation, actual count is 3",
      "evidence": ["알겠습니다", "변동 감지했습니다", "---구분선 3개"]
    },
    {
      "type": "TONE_DRIFT",
      "severity": "LOW",
      "detail": "Self-reported ChatGPT-like but improvement suggestion is vague"
    }
  ],
  "verdict": "FAIL"
}
```

### Stage 3: Periodic Audit (Weekly)

**주간 크론 (일요일 밤, Sonnet 모델):**

```markdown
## 주간 자기평가 감사 보고서 (2026-02-01 ~ 2026-02-07)

### 전체 통계

- 총 크론 실행: 672회
- 자기평가 수행: 672회 (100%)
- External Validation 통과: 584회 (86.9%)
- External Validation 실패: 88회 (13.1%)

### 실패 원인 분석

**1. 부정확한 자기평가 (52회, 59%)**
- Self-reported "OK" but actual errors detected
- Self-reported "Jarvis" but forbidden phrases used
- 예시: "완료!" (forbidden) → self-eval said "✅ 톤: Jarvis"

**2. 포맷 위반 미감지 (28회, 32%)**
- Self-eval: "2 emojis" but actual: 5 emojis
- Self-eval: "1 separator" but actual: 4 separators

**3. 개선 제안 불이행 (8회, 9%)**
- Week 1: "다음엔 환율 포함" → Week 2: 여전히 누락
- Week 3: "ChatGPT 톤 수정" → Week 4: 동일 패턴 반복

### 권장 조치

**즉시 조치 (Critical):**
1. Self-evaluation 기준 명확화
   - "OK"의 정의: 0 tool errors, 0 data inaccuracies
   - "Jarvis"의 정의: 0 forbidden phrases, witty opening
2. Evaluation 전 체크리스트 강제 실행
   - Response Guard 규칙 재확인
   - 금지 표현 스캔 (알겠습니다, 완료, 처리)
   - 포맷 카운트 (이모지, 구분선, 헤더)

**중기 조치 (Important):**
1. Reflection 추가
   - "왜 이렇게 평가했나?" 질문 추가
   - 평가 근거 명시 (예: "OK - yf 스크립트 exit 0")
2. Feedback loop 구현
   - Validation 실패 시 다음 크론에 경고 주입
   - "지난번 당신은 X를 놓쳤습니다. 이번엔 체크하세요."

**장기 조치 (Nice to Have):**
1. LLM-as-Judge (Opus 모델로 일부 재평가)
2. Human-in-the-Loop (월 1회 정우님 리뷰)
```

---

## 구현 우선순위

### Phase 1: 즉시 적용 (오늘)

**1. Stage 2 구현 (External Validation 스크립트)**

- [ ] `scripts/validate-self-review.js` 생성
  - 메트릭 검증
  - 포맷 검증
  - 일관성 검증
- [ ] 모든 self-evaluation 크론에 `+1min` 검증 크론 추가
- [ ] 검증 결과 저장 (`memory/validation-YYYY-MM-DD.jsonl`)

**2. 자기평가 체크리스트 강화**

현재 V2 형식에 추가:
```markdown
## 자기평가 체크리스트 (Pre-Flight)

Before evaluation, I checked:
- [ ] Forbidden phrases scan (알겠습니다, 완료, 처리 등)
- [ ] Emoji count (actual: X, limit: 3)
- [ ] Separator count (actual: Y, limit: 2)
- [ ] Header spacing (blank lines before/after)
- [ ] Tool errors (count: Z)

## 자기평가

✅ 완성도: X/Y [근거: ...]
✅ 정확성: OK [근거: ...]
...
```

### Phase 2: 1주일 내 적용

**3. Reflection 메커니즘 추가**

```markdown
## Reflection (What I Learned)

**What went well:**
- 빠른 응답 (3.2s)
- 정확한 데이터

**What went wrong:**
- 로봇 톤 사용 ("감지했습니다")
- 환율 설명 누락

**Root cause:**
- Response Guard 재확인 안 함
- 스크립트 출력 그대로 전달

**Next time:**
- 응답 전 30초 페르소나 체크
- 환율 데이터 필수 포함 확인
```

**4. Stage 3 구현 (주간 감사 크론)**

- [ ] 일요일 밤 크론 생성 (Sonnet 모델)
- [ ] 최근 7일 validation 결과 분석
- [ ] 패턴 발견 및 보고서 생성
- [ ] 정우님께 Discord 전송

### Phase 3: 1개월 내 적용 (선택)

**5. LLM-as-Judge (Opus 재평가)**

- 주간 감사 시 Validation FAIL 건 중 10개 샘플링
- Opus 모델로 재평가 (Haiku 자기평가 vs Opus 평가 비교)
- 정확도 측정

**6. Dashboard (시각화)**

- `memory/validation-*.jsonl` → 그래프
- Pass rate 트렌드
- 주요 실패 원인 분포
- 개선 효과 측정

---

## 예상 효과

### 정량적 개선

**현재 (V2):**
- 자기평가 수행률: ~50% (AI가 가끔 까먹음)
- 평가 정확도: 알 수 없음
- 개선 반영률: 0%

**V3 적용 후:**
- 자기평가 수행률: 100% (체크리스트 강제)
- 평가 정확도: 90%+ (External Validation으로 검증)
- 개선 반영률: 70%+ (Feedback loop)

### 정성적 개선

1. **신뢰성 향상**
   - "내가 잘했다"는 자기 주장 → "외부 검증 통과"라는 객관적 증거
   - 정우님이 크론 결과를 믿을 수 있음

2. **학습 효과**
   - 같은 실수 반복 방지
   - Reflection으로 근본 원인 파악
   - 주간 감사로 장기 트렌드 파악

3. **자율성 증가**
   - 자가 진단 → 자가 치료
   - 정우님 개입 없이 스스로 개선

---

## 리스크 & 대응

### Risk 1: 토큰 폭증

**문제:** Stage 2 검증 크론 추가 → 크론 2배

**대응:**
- Stage 2는 규칙 기반 (스크립트, LLM 불필요)
- 토큰 사용 0
- Stage 3는 주 1회만

### Risk 2: False Positive

**문제:** External Validation이 잘못된 평가를 FAIL 처리

**대응:**
- Validation 규칙을 점진적으로 튜닝
- 첫 1주일은 log만 (알림 안 함)
- 정확도 80% 이상 확인 후 알림 활성화

### Risk 3: 복잡성 증가

**문제:** 시스템이 너무 복잡해짐

**대응:**
- Phase 1만 먼저 적용 (1-2일 소요)
- 효과 확인 후 Phase 2 결정
- Phase 3는 선택사항

---

## 다음 단계

### 즉시 실행 (정우님 승인 후)

1. ✅ 웹 검색 완료 (최신 방법론 조사)
2. ✅ V3 설계 완료 (이 문서)
3. ⏳ `scripts/validate-self-review.js` 구현
4. ⏳ 14개 크론에 validation 크론 추가
5. ⏳ 체크리스트 강화된 V2.5 형식 배포
6. ⏳ 1주일 모니터링

### 정우님 결정 필요

- **Phase 1 진행 여부:** 즉시 시작? 아니면 더 검토?
- **Phase 2/3 필요성:** 주간 감사까지 갈 것인가?
- **검증 실패 시 알림:** Discord 알림? 아니면 로그만?

---

## 참고 자료

1. **Galileo AI (2025):** Self-Evaluation in AI Agents With Chain of Thought
2. **WEF 2025:** AI Agents in Action Framework
3. **Medium (Dec 2025):** Self-Improving AI Agent That Learns From Feedback
4. **Microsoft Azure (Sep 2025):** Top 5 Agent Observability Best Practices
5. **PwC:** Validating Multi-Agent AI Systems
6. **n8n Blog:** 15 Best Practices for Deploying AI Agents in Production
7. **Anthropic Research:** Bloom - Self-Evaluation Framework
8. **OpenAI Cookbook:** Self-Evolving Agents - Autonomous Retraining

---

**작성:** 2026-02-04 17:57 KST  
**버전:** V3 Draft 1  
**상태:** 정우님 리뷰 대기
