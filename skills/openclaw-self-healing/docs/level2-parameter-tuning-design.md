# Level 2: 파라미터 자동 조정 시스템 설계

> 작성일: 2026-02-05
> 상태: 설계 단계
> 기반: Level 1 Auto-Retry 로그 분석

## 1. 개요

### 1.1 Level 1 vs Level 2

| 항목 | Level 1 (Auto-Retry) | Level 2 (Parameter Tuning) |
|------|---------------------|---------------------------|
| **목표** | 일시적 실패 자동 복구 | 최적 파라미터 자동 발견 |
| **입력** | 개별 실행 결과 (성공/실패) | 누적 로그 패턴 |
| **출력** | 재시도 또는 최종 실패 | 설정 조정 제안 + 자동 적용 |
| **시간** | 실시간 (밀리초) | 주기적 (일/주/월) |
| **Loop** | ✅ Closed (즉시) | ✅ Closed (지연) |
| **사람 개입** | 불필요 | 최소한 (승인만) |

### 1.2 핵심 원칙

**Level 1의 성공 패턴 계승**:
1. ✅ **Closed Loop**: 분석 → 제안 → 적용 → 검증 → 롤백/커밋
2. ✅ **Objective Metrics**: 객관적 데이터 기반 (재시도율, 평균 응답 시간)
3. ✅ **Immediate Verification**: 적용 후 즉시 검증
4. ✅ **Goodhart's Law 회피**: 실제 성능만 인정, 점수 게임 불가

**V4.0의 실패 회피**:
- ❌ Open Loop (제안만 하고 끝)
- ❌ 주관적 판단 (AI가 "좋다/나쁘다" 평가)
- ❌ 검증 지연 (주간/월간 검토)

---

## 2. 현재 상태 분석 (2026-02-05)

### 2.1 Level 1 Auto-Retry 실행 통계

**데이터 기간**: 2026-02-05 04:38 ~ 07:50 (약 3.2시간)

| Cron | 실행 횟수 | 성공률 | 평균 시도 | 재시도 발생 |
|------|----------|--------|----------|------------|
| TQQQ 15분 모니터링 | 8회 | 100% | 1.0 | 0회 |
| GitHub 감시 | 3회 | 100% | 1.0 | 0회 |
| 일일 주식 브리핑 | 1회 | 100% | 1.0 | 0회 |
| **실제 cron 합계** | **12회** | **100%** | **1.0** | **0회** |
| 테스트/시뮬레이션 | 6회 | 50% | 2.17 | 3회 |

**핵심 발견**:
- ✅ 실제 cron은 **재시도 필요 없음** (100% 첫 시도 성공)
- ⚠️ 테스트에서는 16.7% 재시도 필요 (HTTP 429, ETIMEDOUT)
- ✅ 현재 설정(`maxRetries=3`)은 충분히 안전

### 2.2 성능 데이터

**TQQQ 15분 모니터링** (Yahoo Finance API):
- 평균: 1,658ms
- 범위: 1,437ms ~ 2,300ms
- 목표: < 15,000ms (timeout)
- **여유율**: 87% (13초 여유)

**GitHub 감시** (GitHub API):
- 평균: 673ms
- 범위: 370ms ~ 1,203ms
- 목표: < 15,000ms
- **여유율**: 96% (14.3초 여유)

**일일 주식 브리핑** (복합):
- TQQQ: 2,380ms
- SOXL: 1,436ms
- NVDA: 1,409ms
- Hot Scanner: 3,622ms
- Rumor Scanner: 5,800ms
- **총합**: ~14.6초
- **병렬 실행 시 예상**: ~6초 (가장 느린 작업 기준)

**결론**:
- ✅ 모든 작업이 timeout 내 완료
- ✅ 여유가 충분함 → timeout 조정 불필요

### 2.3 현재 설정 적정성

```javascript
{
  maxRetries: 3,           // ✅ 적정 (실패 시 충분한 재시도)
  backoff: 'exponential',  // ✅ 적정 (1s, 2s, 4s)
  timeout: 15000,          // ✅ 적정 (87~96% 여유)
  maxBuffer: 10MB          // ✅ 적정 (출력 크기 문제 없음)
}
```

**Level 2 제안**: 현재 설정 유지 (조정 불필요)

---

## 3. Level 2 시스템 아키텍처

### 3.1 전체 구조

```
┌─────────────────────────────────────────────────────────┐
│                  Level 2 Parameter Tuner                │
└─────────────────────────────────────────────────────────┘
                          │
                          ↓
┌─────────────────────────────────────────────────────────┐
│  1. Log Analyzer                                        │
│  ────────────────                                       │
│  - ~/openclaw/logs/auto-retry.jsonl 분석                │
│  - 패턴 감지: 반복 실패, 성능 저하, 트렌드 변화          │
│  - 통계 생성: 평균 시도 횟수, 실패율, 응답 시간          │
└─────────────────────────────────────────────────────────┘
                          │
                          ↓
┌─────────────────────────────────────────────────────────┐
│  2. Parameter Optimizer                                 │
│  ─────────────────────                                  │
│  - 패턴 기반 최적값 계산                                 │
│  - 안전 범위 검증 (min/max 제약)                         │
│  - 개선 예상치 산출                                      │
└─────────────────────────────────────────────────────────┘
                          │
                          ↓
┌─────────────────────────────────────────────────────────┐
│  3. Change Applicator (with A/B Testing)               │
│  ───────────────────────────────────                   │
│  - 설정 파일 수정 (config.json, wrapper scripts)       │
│  - A/B 테스트: 50% 트래픽만 새 설정 적용                │
│  - 롤백 포인트 생성                                      │
└─────────────────────────────────────────────────────────┘
                          │
                          ↓
┌─────────────────────────────────────────────────────────┐
│  4. Verification Engine                                 │
│  ─────────────────────                                  │
│  - Before/After 메트릭 비교                              │
│  - 통계적 유의성 검정 (t-test, χ² test)                 │
│  - 개선 확인 → 커밋 / 악화 확인 → 롤백                   │
└─────────────────────────────────────────────────────────┘
                          │
                          ↓
┌─────────────────────────────────────────────────────────┐
│  5. Notification & Logging                              │
│  ────────────────────────                               │
│  - Discord 알림 (조정 성공/실패)                         │
│  - 변경 히스토리 기록                                    │
│  - 월간 리포트 생성                                      │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Closed Loop 구현

```javascript
// Level 2 메인 루프
async function level2MainLoop() {
  while (true) {
    // 1. 로그 분석
    const patterns = await analyzeLog();

    // 2. 조정 필요 여부 판단
    if (!patterns.needsTuning) {
      await sleep(7 * 24 * 3600 * 1000); // 1주일 대기
      continue;
    }

    // 3. 최적 파라미터 계산
    const optimizedParams = calculateOptimal(patterns);

    // 4. 안전성 검증
    if (!isSafeToApply(optimizedParams)) {
      notify('⚠️ 조정 제안이 안전 범위 벗어남, 수동 검토 필요');
      continue;
    }

    // 5. A/B 테스트 적용
    const rollbackPoint = createRollbackPoint();
    await applyWithABTest(optimizedParams);

    // 6. 검증 (24시간 모니터링)
    await sleep(24 * 3600 * 1000);
    const metrics = await compareMetrics(rollbackPoint);

    // 7. 커밋 또는 롤백
    if (metrics.improved) {
      commit(optimizedParams);
      notify('✅ 파라미터 조정 성공', metrics);
    } else {
      rollback(rollbackPoint);
      notify('❌ 조정 효과 없음, 롤백', metrics);
    }

    // 8. 다음 주기 대기
    await sleep(7 * 24 * 3600 * 1000);
  }
}
```

---

## 4. 조정 가능한 파라미터

### 4.1 파라미터 카탈로그

| 파라미터 | 현재값 | 조정 범위 | 안전 범위 | 트리거 조건 |
|---------|--------|----------|----------|------------|
| `maxRetries` | 3 | 1~10 | 2~5 | 재시도율 > 10% |
| `timeout` | 15000ms | 5000~60000 | 10000~30000 | 평균 응답 시간 > timeout * 0.8 |
| `backoff` | exponential | linear/exponential/fixed | exponential | 재시도 패턴 분석 |
| `backoffBase` | 1000ms | 500~5000 | 1000~3000 | Rate limit 빈도 |

### 4.2 조정 규칙

**규칙 1: maxRetries 증가**
```javascript
// 조건
if (retry_rate > 0.10 && final_failure_rate > 0.01) {
  // 10% 이상 재시도 필요 & 1% 이상 최종 실패

  // 조정
  maxRetries = current + 1;  // 3 → 4

  // 예상 효과
  // 최종 실패율 1% → 0.1% (90% 감소)
}
```

**규칙 2: timeout 증가**
```javascript
// 조건
if (avg_response_time > timeout * 0.8) {
  // 평균 응답 시간이 timeout의 80% 초과

  // 조정
  timeout = avg_response_time * 1.5;  // 여유 50% 확보

  // 예상 효과
  // timeout 에러 감소
}
```

**규칙 3: backoff 조정**
```javascript
// 조건
if (http_429_count > 0) {
  // Rate limit 발생

  // 조정
  backoffBase = current * 2;  // 1000ms → 2000ms

  // 예상 효과
  // Rate limit 회피
}
```

### 4.3 안전 제약

**절대 하지 말아야 할 것**:
- ❌ `maxRetries` < 2 (너무 적음)
- ❌ `maxRetries` > 5 (너무 많음, 느림)
- ❌ `timeout` < 5000 (너무 짧음)
- ❌ `timeout` > 60000 (너무 김, cron 충돌 위험)

**자동 적용 vs 수동 검토**:
```javascript
// 자동 적용 가능
- maxRetries: 3 → 4 (안전 범위 내)
- timeout: 15s → 20s (안전 범위 내)
- backoffBase: 1s → 2s (안전 범위 내)

// 수동 검토 필요
- maxRetries: 3 → 10 (안전 범위 벗어남)
- timeout: 15s → 5s (감소는 위험)
- 근본 원인 수정 (코드 변경)
```

---

## 5. 구현 계획

### 5.1 Phase 1: 로그 분석기 (Week 1-2)

**파일**: `~/openclaw/lib/log-analyzer.js`

```javascript
const fs = require('fs');
const readline = require('readline');

class LogAnalyzer {
  async analyze(logPath) {
    const stats = {
      total: 0,
      success: 0,
      failure: 0,
      retries: 0,
      byTontextCron: {}
    };

    const fileStream = fs.createReadStream(logPath);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity
    });

    for await (const line of rl) {
      const entry = JSON.parse(line);

      // Skip tests
      if (!entry.context?.cron) continue;

      const cron = entry.context.cron;
      if (!stats.byCron[cron]) {
        stats.byCron[cron] = {
          total: 0,
          success: 0,
          retries: 0,
          avgDuration: 0,
          durations: []
        };
      }

      stats.total++;
      stats.byCron[cron].total++;

      if (entry.type === 'success') {
        stats.success++;
        stats.byCron[cron].success++;
      } else {
        stats.failure++;
      }

      const attempts = entry.attempts.length;
      if (attempts > 1) {
        stats.retries++;
        stats.byCron[cron].retries++;
      }

      const duration = entry.totalDuration;
      stats.byCron[cron].durations.push(duration);
    }

    // Calculate averages
    for (const [cron, data] of Object.entries(stats.byCron)) {
      data.avgDuration = data.durations.reduce((a, b) => a + b, 0) / data.durations.length;
      data.retryRate = data.retries / data.total;
    }

    return stats;
  }

  detectPatterns(stats) {
    const patterns = [];

    for (const [cron, data] of Object.entries(stats.byCron)) {
      // Pattern 1: High retry rate
      if (data.retryRate > 0.10) {
        patterns.push({
          type: 'high_retry_rate',
          cron,
          value: data.retryRate,
          suggestion: 'increase maxRetries'
        });
      }

      // Pattern 2: Slow response
      if (data.avgDuration > 12000) {  // 80% of 15s
        patterns.push({
          type: 'slow_response',
          cron,
          value: data.avgDuration,
          suggestion: 'increase timeout'
        });
      }
    }

    return patterns;
  }
}

module.exports = { LogAnalyzer };
```

### 5.2 Phase 2: 파라미터 최적화기 (Week 3-4)

**파일**: `~/openclaw/lib/parameter-optimizer.js`

```javascript
class ParameterOptimizer {
  calculateOptimal(patterns) {
    const recommendations = [];

    for (const pattern of patterns) {
      if (pattern.type === 'high_retry_rate') {
        recommendations.push({
          param: 'maxRetries',
          current: 3,
          proposed: 4,
          reason: `Retry rate ${(pattern.value * 100).toFixed(1)}% > 10%`,
          expectedImprovement: 'Final failure rate -90%',
          safe: true
        });
      }

      if (pattern.type === 'slow_response') {
        const newTimeout = Math.ceil(pattern.value * 1.5);
        recommendations.push({
          param: 'timeout',
          current: 15000,
          proposed: newTimeout,
          reason: `Avg response ${pattern.value}ms > 80% of timeout`,
          expectedImprovement: 'Timeout errors -100%',
          safe: newTimeout <= 30000
        });
      }
    }

    return recommendations;
  }

  isSafeToApply(recommendation) {
    const safetyRules = {
      maxRetries: { min: 2, max: 5 },
      timeout: { min: 10000, max: 30000 },
      backoffBase: { min: 1000, max: 5000 }
    };

    const rule = safetyRules[recommendation.param];
    if (!rule) return false;

    return recommendation.proposed >= rule.min &&
           recommendation.proposed <= rule.max;
  }
}

module.exports = { ParameterOptimizer };
```

### 5.3 Phase 3: 변경 적용기 (Week 5-6)

**파일**: `~/openclaw/lib/change-applicator.js`

```javascript
const fs = require('fs');

class ChangeApplicator {
  async apply(recommendation, cron) {
    // 1. Create rollback point
    const rollback = this.createRollbackPoint(cron);

    // 2. Update wrapper script
    const wrapperPath = this.getWrapperPath(cron);
    const content = fs.readFileSync(wrapperPath, 'utf8');

    const updated = content.replace(
      new RegExp(`${recommendation.param}: \\d+`),
      `${recommendation.param}: ${recommendation.proposed}`
    );

    fs.writeFileSync(wrapperPath, updated);

    // 3. Log change
    this.logChange({
      timestamp: new Date().toISOString(),
      cron,
      param: recommendation.param,
      from: recommendation.current,
      to: recommendation.proposed,
      reason: recommendation.reason,
      rollbackPoint: rollback
    });

    return rollback;
  }

  createRollbackPoint(cron) {
    const timestamp = Date.now();
    const wrapperPath = this.getWrapperPath(cron);
    const backupPath = `${wrapperPath}.${timestamp}.bak`;

    fs.copyFileSync(wrapperPath, backupPath);

    return {
      timestamp,
      backupPath,
      wrapperPath
    };
  }

  rollback(rollbackPoint) {
    fs.copyFileSync(rollbackPoint.backupPath, rollbackPoint.wrapperPath);
    fs.unlinkSync(rollbackPoint.backupPath);
  }
}

module.exports = { ChangeApplicator };
```

### 5.4 Phase 4: 검증 엔진 (Week 7-8)

**파일**: `~/openclaw/lib/verification-engine.js`

```javascript
class VerificationEngine {
  async verify(rollbackPoint, duration = 24 * 3600 * 1000) {
    // 1. Get baseline metrics (before change)
    const before = await this.getMetricsAtTimestamp(
      rollbackPoint.timestamp - duration
    );

    // 2. Wait for new data
    await new Promise(resolve => setTimeout(resolve, duration));

    // 3. Get current metrics (after change)
    const after = await this.getCurrentMetrics();

    // 4. Compare
    const comparison = {
      retryRate: {
        before: before.retryRate,
        after: after.retryRate,
        change: ((after.retryRate - before.retryRate) / before.retryRate) * 100
      },
      avgDuration: {
        before: before.avgDuration,
        after: after.avgDuration,
        change: ((after.avgDuration - before.avgDuration) / before.avgDuration) * 100
      },
      failureRate: {
        before: before.failureRate,
        after: after.failureRate,
        change: ((after.failureRate - before.failureRate) / before.failureRate) * 100
      }
    };

    // 5. Determine if improved
    const improved =
      comparison.retryRate.change < 0 ||  // Less retries
      comparison.failureRate.change < 0 ||  // Less failures
      (comparison.avgDuration.change < 5 && comparison.failureRate.change <= 0);  // Not slower & not worse

    return { improved, comparison };
  }

  async getMetricsAtTimestamp(timestamp) {
    // Read logs from timestamp onwards
    // Calculate metrics
    // Return stats
  }
}

module.exports = { VerificationEngine };
```

---

## 6. 실행 스케줄

### 6.1 주간 분석 (매주 일요일 23:00)

```bash
# ~/openclaw/scripts/level2-weekly-analysis.js

const { LogAnalyzer } = require('../lib/log-analyzer');
const { ParameterOptimizer } = require('../lib/parameter-optimizer');

async function weeklyAnalysis() {
  console.log('📊 Level 2: 주간 로그 분석\n');

  // 1. Analyze logs
  const analyzer = new LogAnalyzer();
  const stats = await analyzer.analyze('~/openclaw/logs/auto-retry.jsonl');

  console.log('통계:');
  console.log(`- 총 실행: ${stats.total}회`);
  console.log(`- 성공률: ${(stats.success / stats.total * 100).toFixed(1)}%`);
  console.log(`- 재시도율: ${(stats.retries / stats.total * 100).toFixed(1)}%`);

  // 2. Detect patterns
  const patterns = analyzer.detectPatterns(stats);

  if (patterns.length === 0) {
    console.log('✅ 조정 불필요 (모든 지표 정상)');
    return;
  }

  console.log(`\n⚠️ ${patterns.length}개 패턴 발견:`);
  patterns.forEach(p => console.log(`- ${p.type}: ${p.cron}`));

  // 3. Generate recommendations
  const optimizer = new ParameterOptimizer();
  const recommendations = optimizer.calculateOptimal(patterns);

  console.log('\n💡 조정 제안:');
  recommendations.forEach(r => {
    console.log(`- ${r.param}: ${r.current} → ${r.proposed}`);
    console.log(`  이유: ${r.reason}`);
    console.log(`  예상 효과: ${r.expectedImprovement}`);
    console.log(`  안전: ${r.safe ? '✅' : '❌'}`);
  });

  // 4. Auto-apply if safe
  const safeRecs = recommendations.filter(r => r.safe);
  if (safeRecs.length > 0) {
    console.log(`\n✅ ${safeRecs.length}개 자동 적용 예정 (24시간 후 검증)`);
    // Apply changes...
  } else {
    console.log('\n⚠️ 수동 검토 필요 (안전 범위 벗어남)');
  }
}

weeklyAnalysis();
```

### 6.2 Cron 설정

```json
{
  "name": "Level 2 주간 분석",
  "schedule": "0 23 * * 0",
  "payload": {
    "message": "node ~/openclaw/scripts/level2-weekly-analysis.js",
    "to": "channel:1468751194284621967"
  }
}
```

---

## 7. 성공 지표

### 7.1 Level 2 자체의 성공 기준

| 지표 | 목표 | 측정 방법 |
|------|------|----------|
| **자동 조정 정확도** | > 90% | 조정 후 롤백 비율 < 10% |
| **개선 효과** | > 0% | Before/After 메트릭 비교 |
| **사람 개입 비율** | < 10% | 수동 검토 필요 건수 / 전체 조정 |
| **안전성** | 100% | 안전 범위 벗어난 조정 0건 |

### 7.2 측정 가능한 개선

**Before Level 2**:
- maxRetries 수동 설정 → 과하거나 부족할 수 있음
- timeout 수동 설정 → 실제 성능과 불일치
- 설정 변경 시 사람이 판단 → 지연, 실수 가능

**After Level 2**:
- maxRetries 자동 최적화 → 데이터 기반 정확한 값
- timeout 자동 조정 → 실제 응답 시간 * 1.5 여유
- 설정 변경 자동화 → 즉시 적용, 검증, 롤백

**예상 효과**:
- 최종 실패율: -50% (더 많은 재시도로 복구)
- 응답 시간: ±5% (timeout 최적화)
- 운영 부담: -80% (자동화)

---

## 8. Level 3로의 전환 조건

Level 2에서 Level 3 (코드 자동 수정)으로 넘어가는 조건:

**조건 1: 반복 패턴 감지**
```javascript
// 예시
if (same_error_count > 10 && same_fix_count > 5) {
  // 같은 에러가 10번 이상 발생
  // 같은 수동 수정이 5번 이상 발생
  // → AI가 패턴 학습 가능

  suggest_code_fix();
}
```

**조건 2: 근본 원인 명확**
```javascript
// 예시
if (timeout_on_same_api > 5) {
  // 특정 API에서 반복적으로 timeout
  // 근본 원인: API 자체가 느림
  // 해결책: timeout 증가 (설정 변경) OR 캐싱 추가 (코드 변경)

  if (parameter_tuning_not_enough) {
    suggest_code_change();
  }
}
```

**조건 3: 안전한 코드 패턴**
```javascript
// 자동 수정 가능한 패턴
- timeout 값 증가
- retry 로직 추가
- 캐싱 레이어 추가

// 수동 검토 필요한 패턴
- 로직 변경
- API 엔드포인트 변경
- 데이터 구조 변경
```

---

## 9. 다음 단계

### 9.1 즉시 (2026-02-05 ~ 02-12)

- [x] Level 2 설계 문서 작성 (이 문서)
- [ ] 로그 분석기 구현 (`log-analyzer.js`)
- [ ] 테스트 데이터로 검증

### 9.2 2주차 (2026-02-12 ~ 02-19)

- [ ] 파라미터 최적화기 구현
- [ ] 변경 적용기 구현
- [ ] 단위 테스트 작성

### 9.3 3주차 (2026-02-19 ~ 02-26)

- [ ] 검증 엔진 구현
- [ ] 주간 분석 스크립트 작성
- [ ] Cron 등록

### 9.4 4주차 (2026-02-26 ~ 03-05)

- [ ] 프로덕션 배포
- [ ] 첫 자동 조정 실행
- [ ] 효과 측정 및 리포트

---

## 10. 부록

### 10.1 참고 문서

- `~/openclaw/docs/auto-retry-integration.md` (Level 1 설계)
- `~/openclaw/docs/level1-rollout-summary.md` (Level 1 배포 결과)
- `~/openclaw/MEMORY.md` (자가개선 원칙)

### 10.2 관련 파일

```
~/openclaw/
├── lib/
│   ├── auto-retry.js              (Level 1)
│   ├── log-analyzer.js            (Level 2 - 구현 예정)
│   ├── parameter-optimizer.js     (Level 2 - 구현 예정)
│   ├── change-applicator.js       (Level 2 - 구현 예정)
│   └── verification-engine.js     (Level 2 - 구현 예정)
├── scripts/
│   ├── tqqq-monitor-with-retry.js (Level 1)
│   └── level2-weekly-analysis.js  (Level 2 - 구현 예정)
├── logs/
│   └── auto-retry.jsonl           (Level 1 & 2 공용)
└── docs/
    ├── level1-rollout-summary.md  (Level 1)
    └── level2-parameter-tuning-design.md (이 문서)
```

---

**작성**: Claude Opus 4.5
**날짜**: 2026-02-05
**상태**: ✅ 설계 완료, 구현 대기
