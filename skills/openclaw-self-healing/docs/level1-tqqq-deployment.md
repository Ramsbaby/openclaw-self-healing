# Level 1 Auto-Retry - TQQQ 배포

> 배포일: 2026-02-05
> 상태: ✅ 실전 배포 완료

## 개요

TQQQ 15분 모니터링에 Level 1 Auto-Retry 시스템을 적용하여 Yahoo Finance API 일시적 장애 시 자동 복구 가능하게 개선.

## 배포 내용

### 1. 래퍼 스크립트 생성

**파일**: `~/openclaw/scripts/tqqq-monitor-with-retry.js`

```javascript
const { executeWithNotifications } = require('../lib/auto-retry');

async function fetchTQQQ() {
  return new Promise((resolve, reject) => {
    exec(`${CONFIG.PYTHON_SCRIPT} ${CONFIG.SYMBOL}`, {
      timeout: 15000,
      maxBuffer: 10 * 1024 * 1024
    }, (error, stdout, stderr) => {
      if (error) {
        if (error.killed || error.signal === 'SIGTERM') {
          error.code = 'ETIMEDOUT';
        }
        reject(error);
      } else {
        resolve({output: stdout, stderr, duration});
      }
    });
  });
}

const result = await executeWithNotifications(
  fetchTQQQ,
  {
    maxRetries: 3,
    backoff: 'exponential',
    discordWebhook: CONFIG.DISCORD_WEBHOOK,
    taskName: 'TQQQ 15분 모니터링'
  }
);
```

**특징:**
- Python 스크립트 (`~/openclaw/skills/yahoo-finance/yf TQQQ`) 래핑
- 타임아웃 에러 자동 분류 (`ETIMEDOUT`)
- 최대 3회 재시도 (exponential backoff)
- Discord 알림 (재시도 중/성공/실패)
- JSONL 로그 (`~/openclaw/logs/auto-retry.jsonl`)

### 2. 실행 테스트

```bash
$ node ~/openclaw/scripts/tqqq-monitor-with-retry.js

📊 TQQQ 15분 모니터링 (with Auto-Retry)

✅ Success after 1 attempt(s)

✅ Success
   Attempts: 1
   Duration: 1912ms
   Script execution: 1912ms

           📈 TQQQ  POSTPOST
╭─────────────────┬───────────────────╮
│ 항목            │ 값                │
├─────────────────┼───────────────────┤
│ 현재가 (USD)    │ $49.76            │
│ 현재가 (KRW)    │ ₩72,507           │
│ 전일 종가       │ $52.52            │
│ 변동 (전일比)   │ ▼ $2.76 (-5.26%)  │
│ 일중 범위       │ $48.43 ~ $52.15   │
│ 일중 범위 (KRW) │ ₩70,569 ~ ₩75,989 │
│ 거래량          │ 140,842,191       │
│ 환율            │ $1 = ₩1,457.13    │
╰─────────────────┴───────────────────╯

⚠️ 5.3% 변동 - 주의 필요!
```

**결과**: ✅ 첫 시도 성공 (1.9초)

### 3. Cron 설정 업데이트

**파일**: `~/.openclaw/cron/jobs.json`

**변경 사항**:
- Cron ID: `c55df4d3-9dd8-490b-b835-0cea8e744476`
- 이름: "TQQQ 15분 모니터링"
- 스케줄: `*/15 * * * *` (15분마다)

**변경 전**:
```bash
~/openclaw/skills/yahoo-finance/yf TQQQ
```

**변경 후**:
```bash
node ~/openclaw/scripts/tqqq-monitor-with-retry.js
```

## 효과

### Before (재시도 없음)
```
API 타임아웃 → ❌ 즉시 실패 → Discord 에러 알림 → 수동 재실행 필요
```

### After (Level 1 적용)
```
API 타임아웃 → 🔄 자동 재시도 (1초 대기) → ✅ 성공
              → 🔄 재시도 2 (2초 대기) → ✅ 성공
              → 🔄 재시도 3 (4초 대기) → ✅ 성공
              → ❌ 최종 실패 (3회 후)
```

**예상 개선율**:
- 일시적 네트워크 장애: 90% 자동 복구
- 사람 개입 필요: 10%로 감소 (현재 100% → 10%)

## 로그 확인

```bash
# 실시간 모니터링
tail -f ~/openclaw/logs/auto-retry.jsonl

# 최근 TQQQ 실행 기록
jq -r 'select(.context.symbol == "TQQQ")' ~/openclaw/logs/auto-retry.jsonl | tail -10

# 재시도 성공 건수
jq -r 'select(.type == "success" and .attempts.length > 1)' ~/openclaw/logs/auto-retry.jsonl | wc -l
```

## 다음 적용 대상

### 우선순위 1 (외부 API 의존)
- [ ] GitHub Watcher (`~/openclaw/skills/github-watcher/check.sh`)
- [ ] Market Volatility (시장 급변 감지)
- [ ] 일일 주식 브리핑

### 우선순위 2 (네트워크 의존)
- [ ] Trend Hunter
- [ ] 매일 뉴스 분석
- [ ] GitHub 트렌드 감시

### 우선순위 3 (안정성 중요)
- [ ] 월급날 정기투자 알림
- [ ] 환율 모니터링

## 검증 포인트

### 1주차 검증 (2026-02-05 ~ 02-12)
- [ ] 재시도 발생 횟수 확인 (로그 분석)
- [ ] 자동 복구 성공률 측정
- [ ] Discord 알림 정상 작동 확인
- [ ] 최종 실패 건수 확인

### 2주차 확장 (2026-02-12 ~ 02-19)
- [ ] 다른 cron에 적용 (3-5개)
- [ ] 설정 최적화 (backoff, maxRetries)

### 3주차 안정화 (2026-02-19 ~ 02-26)
- [ ] 전체 cron 적용
- [ ] Level 2 설계 (파라미터 자동 조정)

## 기술 상세

### 에러 분류

**재시도 가능** (Retryable):
- Network: `ETIMEDOUT`, `ECONNRESET`, `ENOTFOUND`, `EAI_AGAIN`, `ECONNREFUSED`
- HTTP: 408, 429, 500, 502, 503, 504

**재시도 불가** (Non-retryable):
- HTTP: 400, 401, 403, 404
- File: `ENOENT`
- Logic: 기타 모든 에러

### Backoff 전략

**Exponential** (기본):
```
Attempt 1: 즉시
Attempt 2: 1초 후
Attempt 3: 2초 후
Attempt 4: 4초 후
Attempt 5: 8초 후
```

### Discord 알림 형식

**재시도 중** (Orange):
```
🔄 재시도 중
TQQQ 15분 모니터링 (시도 2/3)

에러: Request timeout
카테고리: timeout
다음 시도: 2000ms 후
```

**성공** (Green):
```
✅ 재시도 성공
TQQQ 15분 모니터링 (2번째 시도에서 성공)
```

**최종 실패** (Red):
```
❌ 최종 실패
TQQQ 15분 모니터링 (3회 시도 후 실패)

제안: Network timeout - check connection or increase timeout
```

## 파일 목록

```
~/openclaw/
├── scripts/
│   └── tqqq-monitor-with-retry.js      (새로 생성)
├── lib/
│   └── auto-retry.js                   (공통 라이브러리)
├── logs/
│   └── auto-retry.jsonl                (자동 생성)
├── docs/
│   ├── auto-retry-integration.md       (통합 가이드)
│   └── level1-tqqq-deployment.md       (이 문서)
└── examples/
    ├── demo-retry.js                   (데모)
    └── auto-retry-usage.js             (사용 예시)
```

## 설정

**CONFIG** (`tqqq-monitor-with-retry.js`):
```javascript
{
  PYTHON_SCRIPT: '~/openclaw/skills/yahoo-finance/yf',
  SYMBOL: 'TQQQ',
  MAX_RETRIES: 3,
  BACKOFF: 'exponential',
  DISCORD_WEBHOOK: '~/.openclaw/monitoring.json',
  POSITION: {
    avgPrice: 50.79,
    shares: 137,
    totalInvested: 10096898
  },
  STRATEGY: {
    stopLoss: 47.00,      // -7.5%
    buyMore: 49.26,       // -3%
    takeProfit: 52.31     // +3%
  }
}
```

## 주의사항

1. **Python 스크립트 변경 금지**
   - 기존 `~/openclaw/skills/yahoo-finance/yf` 스크립트는 변경하지 않음
   - 래퍼만 추가하는 방식으로 호환성 유지

2. **Cron 실행 주기**
   - 15분마다 실행 (`*/15 * * * *`)
   - 최악의 경우 재시도로 최대 7초 소요 (1+2+4)
   - 15분 간격이므로 충분한 여유

3. **Discord 알림**
   - 재시도 발생 시에만 알림 (성공 시 조용)
   - 최종 실패 시 빨간색 알림
   - 알림 spam 방지 (15분당 최대 1회)

4. **로그 관리**
   - JSONL 형식으로 누적 (rotate 필요 시 별도 설정)
   - 위치: `~/openclaw/logs/auto-retry.jsonl`
   - 일주일 후 용량 확인 예정

---

**상태**: ✅ 배포 완료, 실전 모니터링 시작
**다음**: 1주일 후 효과 분석 및 다른 cron 적용 검토
