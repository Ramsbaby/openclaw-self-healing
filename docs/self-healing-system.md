# OpenClaw Self-Healing System

> "시스템이 스스로를 치료하지 못하면 외부 의사를 부른다" — 메타 레벨 자가복구

## 개요

OpenClaw Gateway는 4단계 자가복구(Self-Healing) 시스템으로 장애 상황에서 자동 복구를 시도합니다.

**설계 철학:**
- Level 1-2: 빠른 자동 복구 (초 단위)
- Level 3: 지능형 진단 및 복구 (분 단위)
- Level 4: 인간 개입 요청 (알림)

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│ Level 1: Watchdog (180초 간격)                           │
│ ├─ LaunchAgent: ai.openclaw.watchdog                    │
│ └─ 프로세스 존재 체크 → 재시작                          │
└─────────────────────────────────────────────────────────┘
                         ↓ (프로세스는 살아있지만 먹통)
┌─────────────────────────────────────────────────────────┐
│ Level 2: Health Check (300초 간격)                       │
│ ├─ Script: gateway-healthcheck.sh                       │
│ ├─ LaunchAgent: com.openclaw.healthcheck                │
│ ├─ HTTP 200 응답 검증                                    │
│ ├─ 실패 시 3회 재시도 (30초 간격)                       │
│ └─ 여전히 실패 → Level 3 escalation                     │
└─────────────────────────────────────────────────────────┘
                         ↓ (5분간 복구 실패)
┌─────────────────────────────────────────────────────────┐
│ Level 3: Claude Emergency Recovery (30분 타임아웃)       │
│ ├─ Script: emergency-recovery.sh                        │
│ ├─ tmux로 Claude Code PTY 세션 시작                     │
│ ├─ 자동 진단:                                            │
│ │   - openclaw status                                   │
│ │   - 로그 분석 (~/.openclaw/logs/*.log)               │
│ │   - 설정 검증 (openclaw.json)                        │
│ │   - 포트 충돌 체크 (lsof -i :18789)                  │
│ │   - 의존성 체크 (npm list, node --version)          │
│ ├─ 복구 시도 (설정 수정, 프로세스 재시작)               │
│ ├─ 복구 리포트 생성:                                     │
│ │   - memory/emergency-recovery-report-*.md            │
│ │   - memory/claude-session-*.log                      │
│ └─ 성공/실패 판정 (HTTP 200 체크)                       │
└─────────────────────────────────────────────────────────┘
                         ↓ (Claude 복구도 실패)
┌─────────────────────────────────────────────────────────┐
│ Level 4: Discord Notification (300초 간격 모니터링)      │
│ ├─ Script: emergency-recovery-monitor.sh                │
│ ├─ Cron: eddd4e18-b995-4420-8465-7c6927280228           │
│ ├─ 최근 30분 emergency-recovery 로그 감시               │
│ ├─ "MANUAL INTERVENTION REQUIRED" 패턴 검색             │
│ └─ #jarvis-health 채널에 알림 전송                      │
└─────────────────────────────────────────────────────────┘
```

---

## 구성 요소

### Level 1: Watchdog

**파일:**
- `~/Library/LaunchAgents/ai.openclaw.watchdog.plist`

**동작:**
- 180초마다 OpenClaw 프로세스 존재 확인
- 프로세스 없으면 자동 재시작

**한계:**
- 프로세스는 살아있지만 HTTP 응답 못하는 경우 감지 불가

---

### Level 2: Health Check

**파일:**
- `~/openclaw/scripts/gateway-healthcheck.sh`
- `~/Library/LaunchAgents/com.openclaw.healthcheck.plist`

**동작:**
1. HTTP GET `http://localhost:18789/` → 200 체크
2. 실패 시 재시작 (30초 대기)
3. 3회 재시도
4. 여전히 실패 → 5분 대기
5. 5분 후에도 실패 → Level 3 트리거

**로그:**
- `~/openclaw/memory/healthcheck-YYYY-MM-DD.log`

**설치:**
```bash
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

**제거:**
```bash
launchctl unload ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
```

---

### Level 3: Claude Emergency Recovery

**파일:**
- `~/openclaw/scripts/emergency-recovery.sh`

**동작:**
1. tmux 세션 생성: `emergency_recovery_TIMESTAMP`
2. Claude Code 실행 (`claude`)
3. 워크스페이스 신뢰 (자동 Enter)
4. 긴급 복구 명령 전송:
   ```
   OpenClaw 게이트웨이가 5분간 재시작했으나 복구되지 않았습니다.
   긴급 진단 및 복구를 시작하세요.
   
   작업 순서:
   1. openclaw status 체크
   2. 로그 분석 (~/.openclaw/logs/*.log)
   3. 설정 검증 (~/.openclaw/openclaw.json)
   4. 포트 충돌 체크 (lsof -i :18789)
   5. 의존성 체크 (npm list, node --version)
   6. 복구 시도 (설정 수정, 프로세스 재시작)
   7. 결과를 memory/emergency-recovery-report-*.md 에 기록
   ```
5. 30분 대기
6. 복구 결과 확인 (HTTP 200 체크)
7. tmux 세션 캡처 및 종료

**출력 파일:**
- `~/openclaw/memory/emergency-recovery-TIMESTAMP.log` (실행 로그)
- `~/openclaw/memory/claude-session-TIMESTAMP.log` (Claude 세션 캡처)
- `~/openclaw/memory/emergency-recovery-report-TIMESTAMP.md` (Claude 생성, 옵션)

**수동 실행:**
```bash
~/openclaw/scripts/emergency-recovery.sh
```

---

### Level 4: Discord Notification

**파일:**
- `~/openclaw/scripts/emergency-recovery-monitor.sh`

**동작:**
1. 최근 30분 내 `emergency-recovery-*.log` 파일 검색
2. "MANUAL INTERVENTION REQUIRED" 패턴 검색
3. 발견 시 #jarvis-health 채널에 알림
4. 중복 알림 방지 (`.emergency-alert-sent` 파일)

**Cron 설정:**
- **ID:** `eddd4e18-b995-4420-8465-7c6927280228`
- **주기:** 5분 (`everyMs: 300000`)
- **세션:** isolated
- **모델:** claude-haiku-4-5
- **채널:** Discord #jarvis-health (1468429321738911947)

**알림 형식:**
```
🚨 긴급: OpenClaw 자가복구 실패

시간: YYYY-MM-DD-HHMM
상태:
- Level 1 (Watchdog) ❌
- Level 2 (Health Check) ❌  
- Level 3 (Claude Recovery) ❌

수동 개입 필요합니다.

로그:
- ~/openclaw/memory/emergency-recovery-*.log
- ~/openclaw/memory/claude-session-*.log
- ~/openclaw/memory/emergency-recovery-report-*.md (Claude 생성)
```

---

## 테스트 시나리오

### 1. Level 1 테스트 (Watchdog)

**시나리오:** 프로세스 강제 종료

```bash
# Gateway PID 확인
ps aux | grep openclaw-gateway | grep -v grep

# 강제 종료
kill -9 <PID>

# 3분 이내 자동 재시작 확인
sleep 180
curl http://localhost:18789/
```

**예상 결과:**
- Watchdog가 180초 이내 프로세스 재시작
- HTTP 200 응답 복구

---

### 2. Level 2 테스트 (Health Check)

**시나리오:** HTTP 응답 실패 (포트 블록)

```bash
# 포트 블록 (방화벽 규칙 또는 프록시 설정)
# 또는 openclaw.json에서 잘못된 포트 설정

# Health Check 로그 모니터링
tail -f ~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log
```

**예상 결과:**
- Health Check가 HTTP 실패 감지
- 3회 재시도 (30초 간격)
- 5분 후에도 실패 시 Level 3 트리거

---

### 3. Level 3 테스트 (Claude Recovery)

**시나리오:** 설정 오류 주입

```bash
# openclaw.json 백업
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak

# 의도적 오류 주입 (예: 잘못된 포트)
# (수동 편집 필요)

# Gateway 재시작
openclaw gateway restart

# Emergency Recovery 트리거 대기 (최대 8분)
# - Health Check 감지: ~5분
# - Level 3 시작: +30분

# 로그 모니터링
tail -f ~/openclaw/memory/emergency-recovery-*.log
```

**예상 결과:**
- Claude가 설정 오류 감지
- 설정 수정 시도
- 복구 리포트 생성
- HTTP 200 복구 또는 실패 리포트

---

### 4. Level 4 테스트 (Discord Notification)

**시나리오:** Level 3 실패 시뮬레이션

```bash
# Level 3 실패 로그 수동 생성
cat > ~/openclaw/memory/emergency-recovery-test-$(date +%Y-%m-%d-%H%M).log << 'EOF'
[2026-02-05 20:00:00] === Emergency Recovery Started ===
[2026-02-05 20:30:00] Gateway still unhealthy after Claude recovery (HTTP 500)

=== MANUAL INTERVENTION REQUIRED ===
Level 1 (Watchdog) ❌
Level 2 (Health Check) ❌
Level 3 (Claude Recovery) ❌
EOF

# Monitor 스크립트 실행 (또는 크론 대기)
~/openclaw/scripts/emergency-recovery-monitor.sh
```

**예상 결과:**
- Discord #jarvis-health에 알림 전송
- 중복 알림 방지 기록 생성

---

## 운영 가이드

### 상태 확인

```bash
# LaunchAgent 상태
launchctl list | grep openclaw

# Health Check 로그
tail -f ~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log

# Emergency Recovery 로그
ls -lt ~/openclaw/memory/emergency-recovery-*.log | head -5

# Cron 상태
openclaw cron list | grep "Emergency Recovery"
```

---

### 수동 복구

Level 3 실패 시 수동 복구 절차:

```bash
# 1. 로그 확인
tail -100 ~/.openclaw/logs/gateway.log
tail -100 ~/.openclaw/logs/gateway.err.log

# 2. 설정 검증
openclaw doctor --non-interactive

# 3. 포트 충돌 체크
lsof -i :18789

# 4. 의존성 체크
node --version
npm list -g openclaw

# 5. Gateway 완전 재시작
openclaw gateway stop
sleep 5
openclaw gateway start

# 6. 복구 확인
curl -i http://localhost:18789/
```

---

### 비활성화

시스템 유지보수 또는 디버깅 시:

```bash
# Health Check 비활성화
launchctl unload ~/Library/LaunchAgents/com.openclaw.healthcheck.plist

# Emergency Recovery Monitor 크론 비활성화
openclaw cron disable eddd4e18-b995-4420-8465-7c6927280228

# 재활성화
launchctl load ~/Library/LaunchAgents/com.openclaw.healthcheck.plist
openclaw cron enable eddd4e18-b995-4420-8465-7c6927280228
```

---

## 모니터링 메트릭

**추적 지표:**

| 지표 | 수집 위치 | 목표 |
|------|----------|------|
| Health Check 성공률 | healthcheck-*.log | > 99% |
| Level 1 복구 횟수 | watchdog.log | < 1/day |
| Level 2 복구 횟수 | healthcheck-*.log | < 1/week |
| Level 3 트리거 횟수 | emergency-recovery-*.log | 0/month |
| Level 4 알림 횟수 | Discord #jarvis-health | 0/month |
| 평균 복구 시간 | healthcheck-*.log | < 5분 (Level 1-2) |

**주간 리뷰 (일요일 23:30 감사 크론):**
- Health Check 로그 분석
- Level 3 트리거 이력 확인
- 반복 패턴 식별
- 시스템 개선 제안

---

## 제한사항

1. **Claude Code 의존성**
   - Level 3는 Claude CLI 설치 필요
   - Claude API 할당량 소진 시 Level 3 실패 가능

2. **tmux 의존성**
   - PTY 세션에 tmux 필요
   - tmux 설치 안 되어 있으면 Level 3 불가

3. **네트워크 장애**
   - Claude API 접근 불가 시 Level 3 실패
   - Discord API 접근 불가 시 Level 4 알림 실패

4. **macOS 전용**
   - LaunchAgent는 macOS 전용
   - Linux는 systemd 변환 필요

---

## 확장 계획

**Phase 2 (미래):**
- [ ] GitHub Issues 자동 생성 (Level 4 실패 시)
- [ ] Telegram 알림 추가 (이중화)
- [ ] Prometheus 메트릭 수집
- [ ] Grafana 대시보드 구축
- [ ] Multi-node 지원 (클러스터 환경)

---

## 참고 자료

- [OpenClaw Docs](https://docs.openclaw.ai)
- [Moltbook: Nightly Build Pattern](https://moltbook.com) (Level 3 영감)
- [Moltbook: Reliability Check](https://moltbook.com) (Health Check 영감)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)

---

**작성일:** 2026-02-05  
**최종 업데이트:** 2026-02-05  
**작성자:** Jarvis (Self-Healing System Implementation)
