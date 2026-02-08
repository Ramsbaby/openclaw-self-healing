# 크론 자기평가 로깅 베스트 프랙티스 분석

## 웹 검색 결과 요약

### AI Agent 로깅 (2025)
> "Log every step: Track all actions, tool/API calls, decisions"
> "Real-time monitoring + periodic quality checks"
> "Log retention periods depend on business needs"

**핵심:** 모든 액션 추적 + 주기적 품질 검토

---

### 로그 로테이션 업계 표준

#### 고트래픽 시스템
> "**Daily rotation is ideal for high-traffic systems** that generate a lot of logs quickly"
> "Daily rotation is recommended for a busy web server"

#### 중저트래픽
> "Weekly rotation works well for most moderate-use applications"
> "Monthly rotation is typically enough for systems with low log activity"

**우리 상황:**
- TQQQ: 15분 간격 = 96회/일
- 총 14개 주기적 크론 = 100+ 로그/일
- **→ 고트래픽 → Daily rotation 권장**

---

### 크론 잡 로깅 전략

> "**Redirect the output to a separate log file to maintain the record**"
> "Always specify a full path and redirect output to separate log file"

**핵심:** 크론 로그는 별도 파일에

---

## 4가지 옵션 재평가

### Option 1: 예외만 기록
```
✅ OK → 기록 안 함
⚠️ WARNING → 기록
```

**평가:**
- ❌ "Log every step" 원칙 위반
- ❌ 정상 패턴 파악 불가
- ❌ 트렌드 분석 불가

**베스트 프랙티스 일치도: 30%**

---

### Option 2: 별도 파일 (월간)
```
memory/self-review-2026-02.md  # 월별 1개 파일
```

**평가:**
- ✅ "Separate log file" 권장사항 준수
- ⚠️ 한 달 = 96회/일 * 30일 = 2,880회
- ⚠️ 파일 크기: ~8,000줄 (관리 가능하나 검색 느림)
- ✅ 메인 로그 노이즈 제거

**베스트 프랙티스 일치도: 70%**

---

### Option 2-B: 별도 파일 (일간) ⭐⭐⭐
```
memory/self-review-2026-02-04.md  # 일별 파일
```

**평가:**
- ✅ "Daily rotation for high-traffic" 완벽 일치
- ✅ "Separate log file" 준수
- ✅ 파일 크기: ~300줄/일 (이상적)
- ✅ 날짜별 검색 용이
- ✅ 자동 삭제 쉬움 (7일 이전 파일)
- ✅ 메인 로그 노이즈 제거

**베스트 프랙티스 일치도: 95%**

---

### Option 3: 주간 요약
```
매일 기록 X
일요일 밤 요약 O
```

**평가:**
- ❌ "Log every step" 위반
- ❌ 디버깅 불가 (raw data 없음)
- ❌ 업계 표준 없음

**베스트 프랙티스 일치도: 20%**

---

### Option 4: 집계 통계
```
[23:00] 크론 자기평가 요약 (오늘)
- TQQQ: 96회, 94회 OK, 2회 WARNING
```

**평가:**
- ⚠️ "Log every step" 부분 위반
- ⚠️ 개별 실행 추적 불가
- ✅ 트렌드 파악 가능
- ❌ 구현 복잡

**베스트 프랙티스 일치도: 60%**

---

## 최종 결론

### 🏆 Winner: Option 2-B (Daily Separate File)

**구조:**
```
memory/
├── 2026-02-04.md                  # 중요 이벤트 (사람이 읽기)
├── self-review-2026-02-04.md      # 크론 자기평가 (트러블슈팅용)
└── self-review-2026-02-03.md
```

**형식:**
```markdown
# 크론 자기평가 - 2026-02-04

## 16:30 TQQQ 15분 모니터링
✅ 완성도: 5/5
✅ 정확성: OK
✅ 톤: Jarvis
✅ 간결성: 2 emojis
✅ 가독성: 헤더/테이블
💡 개선: 환율 설명 1줄 축약

## 17:00 Daily Wrap-up
...
```

**로테이션 정책:**
- 보관: 7일
- 7일 이전: 자동 삭제 (주간 크론)
- 월말: 요약 통계 생성 (optional)

---

## 추천 이유 (베스트 프랙티스 기준)

1. **업계 표준 완벽 준수**
   - 고트래픽 → Daily rotation ✅
   - 크론 로그 → Separate file ✅
   - AI agent → Log every step ✅

2. **실용성**
   - 파일 크기: ~300줄/일 (grep 1초)
   - 검색: `grep "WARNING" memory/self-review-*.md`
   - 삭제: `find memory/ -name "self-review-*.md" -mtime +7 -delete`

3. **확장성**
   - 크론 추가돼도 문제없음
   - 간격 줄어도 관리 가능 (5분 간격까지)
   - 분석 도구 붙이기 쉬움

4. **유지보수**
   - 자동 로테이션 (날짜별 파일명)
   - 디스크 사용량 예측 가능 (~2MB/일)
   - 백업 간단 (날짜 범위 지정)

---

## 구현 변경사항

### AGENTS.md 수정
```diff
- memory/YYYY-MM-DD.md에 평가 기록 (간단히 2-3줄)
+ memory/self-review-YYYY-MM-DD.md에 평가 기록
```

### 주간 크론 추가 (로그 정리)
```bash
# 매주 일요일 23:50 - 7일 이전 자기평가 로그 삭제
find ~/openclaw/memory/ -name "self-review-*.md" -mtime +7 -delete
```

### 월간 리포트 (Optional)
```bash
# 매월 1일 00:00 - 지난달 통계 생성
grep -h "^## " memory/self-review-2026-01-*.md | wc -l
# → "1월 총 크론 실행: 3,024회"
```

---

## 결론

**Option 2-B (Daily Separate File)가 압도적 1위**
- 베스트 프랙티스 일치도: 95%
- 구현 단순함: ⭐⭐⭐⭐⭐
- 유지보수성: ⭐⭐⭐⭐⭐
- 확장성: ⭐⭐⭐⭐⭐

**나머지:**
- Option 1: 20% (데이터 손실)
- Option 2-A: 70% (파일 너무 큼)
- Option 3: 20% (업계 표준 위반)
- Option 4: 60% (구현 복잡 + 디버깅 불가)
