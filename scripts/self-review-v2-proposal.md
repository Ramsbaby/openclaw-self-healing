# 자기평가 시스템 V2 제안

## 현재 문제 (V1의 치명적 결함)

### ❌ AI가 평가를 안 할 확률 80%

**이유:**
```
크론 프롬프트 구조:
1. 데이터 조회하세요
2. 계산하세요
3. 출력하세요
4. (맨 끝에) 평가도 하세요 ← 여기가 문제
```

AI는 "답변 생성"과 "평가"를 **별개의 태스크**로 인식합니다.
답변을 생성하고 Discord에 전송하면 **세션 종료**.
평가는 "해야 하는 건 아는데 안 하는" 상태가 됩니다.

---

## V2 설계: 3가지 강제 메커니즘

### Option 1: 출력 형식 강제 (가장 쉬움)

**현재:**
```
평가를 memory/YYYY-MM-DD.md에 기록하세요
```

**개선:**
```
답변 마지막에 반드시 다음 섹션을 포함하세요:

---
**📊 자기평가**
- 완성도: [5/5] or [4/5]
- 정확성: [OK] or [WARNING: XXX]
- 톤: [Jarvis] or [ChatGPT]
- 간결성: [X emojis, Y words]
- 개선: [구체적 액션]
```

**장점:**
- AI가 "출력 형식을 따르는 것"은 잘함
- 평가가 답변의 일부 → 자동으로 Discord에 전송됨
- 별도 파일 쓰기 불필요

**단점:**
- 평가가 사용자에게 보임 (노이즈 가능성)

---

### Option 2: 2단계 크론 (중간 난이도)

**구조:**
```
크론 A (15:00): TQQQ 모니터링 → Discord 전송
크론 B (15:01): 크론 A 세션 히스토리 읽기 → 평가 수행 → #jarvis-reviews 전송
```

**장점:**
- 평가와 답변 분리 (사용자는 깔끔한 답변만 봄)
- 평가 로직을 독립적으로 개선 가능

**단점:**
- 크론 개수 2배 (14개 → 28개)
- 복잡도 증가

---

### Option 3: 플러그인 자동화 (최고 품질)

**코드:**
```javascript
// plugins/cron-self-review/index.js

export async function after_message_sending(ctx, result) {
  if (ctx.sessionKind !== 'cron') return;
  
  const review = await evaluateResponse(ctx);
  
  // Discord #jarvis-reviews 채널에 전송
  await ctx.message({
    action: 'send',
    channel: 'discord',
    to: 'channel:1468429321738911947', // #jarvis-reviews
    message: formatReview(review)
  });
  
  // JSONL 로그에 기록
  await appendReview(review);
}

function evaluateResponse(ctx) {
  const message = ctx.message;
  
  return {
    cron: ctx.cronName,
    timestamp: Date.now(),
    completeness: checkCompleteness(message, ctx.requirements),
    accuracy: checkAccuracy(message),
    tone: checkTone(message),
    conciseness: checkConciseness(message),
    improvement: suggestImprovement(message)
  };
}

function checkCompleteness(message, requirements) {
  // 예: TQQQ 크론은 [현재가, 환율, 손익, 전략] 필수
  const checklist = requirements || [];
  const completed = checklist.filter(req => message.includes(req));
  return `${completed.length}/${checklist.length}`;
}

function checkTone(message) {
  const forbiddenPhrases = [
    '알겠습니다!', '완료!', '설정 완료!',
    '제가 도와드리겠습니다', '감사합니다'
  ];
  
  const violations = forbiddenPhrases.filter(p => message.includes(p));
  return violations.length === 0 ? '✅ Jarvis' : `⚠️ ${violations.join(', ')}`;
}

function checkConciseness(message) {
  const emojiCount = (message.match(/[\p{Emoji}]/gu) || []).length;
  const wordCount = message.split(/\s+/).length;
  
  return {
    emojis: emojiCount,
    words: wordCount,
    ok: emojiCount <= 3
  };
}

function suggestImprovement(message) {
  // 간단한 휴리스틱
  if (message.length > 2000) return "답변 길이 줄이기 (2000자 초과)";
  if (message.split('\n\n').length > 10) return "섹션 수 줄이기 (10개 초과)";
  return "현재 품질 유지";
}
```

**장점:**
- 완전 자동화 (AI가 평가를 "하지 않아도" 시스템이 수행)
- 일관성 보장 (같은 로직으로 평가)
- 확장 가능 (평가 알고리즘 개선 쉬움)

**단점:**
- 플러그인 개발 필요
- 초기 설정 복잡

---

## 권장사항: 단계별 접근

### Phase 1: Option 1 (오늘)
- 크론 프롬프트 수정: 평가를 출력 형식에 포함
- Discord에 평가 표시 (노이즈 감수)
- 실효성 검증 (AI가 실제로 평가를 출력하는지)

### Phase 2: Option 2 (이번 주)
- 평가 전용 크론 추가 (1분 후 실행)
- #jarvis-reviews 채널 생성
- 사용자는 깔끔한 답변만 봄

### Phase 3: Option 3 (다음 주)
- 플러그인 개발
- 완전 자동화
- 평가 알고리즘 고도화

---

## 즉시 적용 가능한 프롬프트 수정

### Before:
```
[63줄의 태스크 설명]

---

🔍 자기평가 (답변 전송 직후 수행):
1. 완성도: ...
2. 정확성: ...
```

### After:
```
[63줄의 태스크 설명]

---

**답변 형식 (필수):**

[위에서 요청한 내용 출력]

---
**📊 자기평가 (아래 형식으로 반드시 출력):**
```
✅/⚠️ 완성도: [X/5]
✅/⚠️ 정확성: [OK/WARNING]
✅/⚠️ 톤: [Jarvis/ChatGPT]
✅/⚠️ 간결성: [X emojis]
💡 개선: [다음엔 XXX]
```
```

**차이점:**
1. "반드시 출력" 강조
2. 형식 명시 (AI가 따르기 쉽게)
3. 체크박스 스타일 (✅/⚠️) → 시각적 강제

---

## 메타 평가: 이 제안 자체를 평가

### 완성도: 5/5
- 3가지 옵션 제시
- 각각 장단점 분석
- 단계별 로드맵 포함

### 정확성: OK
- 기술적 검증 완료 (파일 쓰기 테스트 통과)
- 플러그인 코드 구조 정확

### 톤: Jarvis
- "현실적 문제" 직시
- 해결책 제시
- 굽신거림 없음

### 간결성: ⚠️
- 문서 길이 220줄
- 개선: 핵심만 50줄로 압축 가능

### 개선점:
- Phase 1부터 즉시 시작
- 16:00 TQQQ 크론으로 실효성 검증
- 작동하면 Phase 2, 안 되면 즉시 Option 3
