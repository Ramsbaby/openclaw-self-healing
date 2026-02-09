# Self-Improvement System V4.0 설정 가이드

> 작성일: 2026-02-05
> 버전: V4.0 (V3.3 → V4.0 업그레이드)

## 개요

Self-Improvement System V4.0은 기존 V3.3에 다음 기능을 추가합니다:

**V3.3 (기존)**:
- ✓ 점수 시스템 폐지
- ✓ 객관적 지표
- ✓ 실패/미흡 필수
- ✓ 주간 외부 검증

**V4.0 (신규)**:
- ✅ 목표 대비 측정 (응답 시간 <15초 등)
- ✅ CoT (Chain of Thought) - 의사결정 추론
- ✅ 자동 패턴 탐지
- ✅ 일일 자동 체크

## 파일 구조

```
~/openclaw/
├── templates/
│   ├── self-review-v3.3.md (기존)
│   └── self-review-v4.0.md (신규) ← 새 템플릿
├── scripts/
│   ├── detect-patterns.js (신규) ← 패턴 탐지
│   └── daily-self-check.js (신규) ← 일일 체크
├── memory/
│   ├── self-review-YYYY-MM-DD.md (리뷰 기록)
│   ├── pattern-alerts-YYYY-MM-DD.json (패턴 알림 기록)
│   └── pattern-alert-history.json (알림 히스토리)
└── docs/
    └── self-improvement-v4-setup.md (이 문서)
```

## 1단계: V4.0 템플릿 적용

### A. 시범 적용 (권장)

먼저 5개 cron에만 V4.0을 적용하여 테스트:

```bash
# OpenClaw Gateway가 실행 중인지 확인
openclaw gateway status

# 시범 적용할 cron 선택 (예시)
# - TQQQ 15분 모니터링
# - Market Volatility 체크
# - GitHub Watcher
# - Disk Check
# - Weekly Summary
```

### B. 템플릿 교체

**방법 1: 수동 교체 (안전)**

각 cron의 메시지에서 템플릿 경로 변경:

```
변경 전:
~/openclaw/templates/self-review-v3.3.md 참고하여 품질 체크 수행

변경 후:
~/openclaw/templates/self-review-v4.0.md 참고하여 품질 체크 수행
```

**방법 2: 스크립트 업데이트 (빠름)**

`~/openclaw/scripts/add-self-review.js` 수정 필요 시:

```javascript
// Template path 변경
const TEMPLATE_PATH = path.join(
  process.env.HOME,
  'openclaw/templates/self-review-v4.0.md' // v3.3 → v4.0
);
```

### C. 목표 설정

각 cron에 맞는 목표 설정:

| Cron 유형 | 응답 목표 | 도구 실패율 | 특이사항 |
|----------|----------|------------|----------|
| 단순 체크 | <10초 | <3% | Disk, Memory 등 |
| 데이터 수집 | <15초 | <5% | Market, Weather 등 |
| 복잡한 분석 | <30초 | <8% | Weekly Summary 등 |
| API 호출 많음 | <20초 | <10% | GitHub, 외부 API 등 |

## 2단계: 자동화 설정

### A. 패턴 탐지 (주 1회)

**cron 추가 (매주 일요일 23:00)**:

```bash
openclaw cron add \
  --id "pattern-detection-weekly" \
  --schedule "0 23 * * 0" \
  --message "~/openclaw/scripts/detect-patterns.js 실행하여 지난 7일간 반복 패턴 탐지. 3회 이상 반복된 실패/미흡 패턴 발견 시 Discord 알림." \
  --model "haiku" \
  --isolation "enabled"
```

또는 직접 실행:

```bash
# 수동 실행
node ~/openclaw/scripts/detect-patterns.js

# crontab 추가 (Gateway 없이)
0 23 * * 0 node ~/openclaw/scripts/detect-patterns.js
```

### B. 일일 체크 (매일 06:00)

**cron 추가**:

```bash
openclaw cron add \
  --id "daily-self-check" \
  --schedule "0 6 * * *" \
  --message "~/openclaw/scripts/daily-self-check.js 실행하여 어제 self-review 검토. 최근 3일과 비교하여 반복 패턴 즉시 알림." \
  --model "haiku" \
  --isolation "enabled"
```

또는:

```bash
# crontab 추가
0 6 * * * node ~/openclaw/scripts/daily-self-check.js
```

### C. 알림 테스트

Discord 알림이 정상 작동하는지 확인:

```bash
# 패턴 탐지 테스트
node ~/openclaw/scripts/detect-patterns.js

# 일일 체크 테스트
node ~/openclaw/scripts/daily-self-check.js
```

## 3단계: 모니터링 및 검증

### A. 첫 주 (Feb 5-11)

- [ ] V4.0 템플릿으로 5개 cron 실행
- [ ] 목표 달성률 확인 (✓/✗ 분포)
- [ ] CoT 섹션 품질 평가
- [ ] 패턴 탐지 스크립트 1회 실행

### B. 둘째 주 (Feb 12-18)

- [ ] V4.0 전체 확대 (23개 cron)
- [ ] 일일 체크 활성화
- [ ] 첫 주간 트렌드 분석
- [ ] V3.3과 V4.0 비교

### C. A/B Testing (선택)

**실험군**: 10개 cron → V4.0
**대조군**: 10개 cron → V3.3 유지

4주 후 비교:
- 목표 달성률 차이
- 실패/미흡 개선 속도
- 같은 실수 반복 빈도

## 4단계: 주간 리포트

매주 일요일 23:30 Opus 검증에 추가:

```markdown
## V4.0 검증 항목 (추가)

### 목표 달성률 분석
- 응답 시간 목표: X/Y 달성 (Z%)
- 재시도 0회: X/Y 달성 (Z%)
- 도구 실패율 <5%: X/Y 달성 (Z%)

### CoT 품질 평가
- 의사결정 추론 명확성: 상/중/하
- 트레이드오프 고려: 충분/부족
- 개선 제안 활용 가능성: 높음/중간/낮음

### 트렌드
- 평균 응답 시간: 이번 주 vs 지난 주
- 도구 실패율: 이번 주 vs 지난 주
- 반복 패턴: 감소/유지/증가
```

## 5단계: 문제 해결

### Q1. Discord 알림이 안 옴

```bash
# Webhook URL 확인
cat ~/.openclaw/monitoring.json | grep webhook

# 수동 테스트
curl -X POST "https://discord.com/api/webhooks/..." \
  -H "Content-Type: application/json" \
  -d '{"content":"Test from daily-self-check"}'
```

### Q2. 패턴 탐지 결과가 너무 많음

`~/openclaw/scripts/detect-patterns.js` 조정:

```javascript
// Line 24
REPETITION_THRESHOLD: 3, // 3 → 4 (더 엄격하게)
SIMILARITY_THRESHOLD: 0.6, // 0.6 → 0.7 (더 유사해야 매칭)
```

### Q3. 일일 체크가 매번 알림

정상입니다. 실제로 반복되는 실패가 있다는 의미.

해결:
1. "즉시 개선" 항목 실제로 적용했는지 확인
2. `.learnings/LEARNINGS.md`에 기록
3. 근본 원인 해결

### Q4. V4.0 템플릿이 너무 복잡함

간소화 버전 사용:

```markdown
│ **객관 지표**
│ 　도구: X회 / Y실패 (Z%)
│ 　응답: X초 [✓/✗]
│ 　재시도: X회 [✓/✗]
│
│ **실패/미흡**
│ 　• [구체적 사항]
│
│ **즉시 개선**
│ 　• [다음부터 적용]
```

CoT 섹션은 선택 사항.

## 6단계: 다음 개선 (Week 2+)

### 단기 (1-2주)

- [ ] KPI Dashboard 생성
- [ ] Learning 우선순위 자동화
- [ ] 월간 트렌드 리포트

### 중기 (2-4주)

- [ ] Observability Hooks
- [ ] Self-Correction 프로토타입
- [ ] 벤치마크 비교

## 참고 자료

### 스크립트 사용법

**패턴 탐지**:
```bash
# 기본 실행 (7일 스캔)
node ~/openclaw/scripts/detect-patterns.js

# 설정 변경
# CONFIG.DAYS_TO_SCAN: 7 → 14 (더 긴 기간)
# CONFIG.REPETITION_THRESHOLD: 3 → 2 (더 민감하게)
```

**일일 체크**:
```bash
# 기본 실행 (어제 + 최근 3일)
node ~/openclaw/scripts/daily-self-check.js

# 설정 변경
# CONFIG.DAYS_TO_CHECK: 4 → 7 (더 긴 윈도우)
# CONFIG.SIMILARITY_THRESHOLD: 0.65 → 0.7 (더 엄격)
```

### Discord 알림 형식

**패턴 탐지**: 🚨 빨간색 (심각)
**일일 체크**: ⚠️ 주황색 (경고)

### 백업 및 복구

```bash
# V3.3 템플릿 백업
cp ~/openclaw/templates/self-review-v3.3.md \
   ~/openclaw/templates/self-review-v3.3.backup.md

# V4.0 롤백 (필요 시)
# 모든 cron 메시지에서 v4.0 → v3.3으로 변경
```

## 체크리스트

### 설치 완료

- [ ] `self-review-v4.0.md` 생성 완료
- [ ] `detect-patterns.js` 실행 가능
- [ ] `daily-self-check.js` 실행 가능
- [ ] Discord 알림 테스트 성공

### V4.0 전환

- [ ] 시범 cron 5개 선택
- [ ] 템플릿 경로 변경
- [ ] 목표 설정 (cron별)
- [ ] 첫 실행 확인

### 자동화

- [ ] 패턴 탐지 cron 추가
- [ ] 일일 체크 cron 추가
- [ ] Discord 알림 작동 확인
- [ ] 주간 검증 항목 업데이트

### 모니터링

- [ ] 첫 주 결과 검토
- [ ] V3.3 vs V4.0 비교
- [ ] 개선 사항 적용
- [ ] 전체 확대 결정

---

**문의**: Discord `#openclaw-health` 채널
**버전**: V4.0 (2026-02-05)
**다음 업데이트**: V4.1 (KPI Dashboard, 예정 2026-02-12)
