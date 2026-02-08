---
title: "OpenClaw 자가복구 시스템 Part 3 - 시스템 통합과 운영 노하우"
date: 2026-02-08
category: AI
tags: [OpenClaw, DevOps, LaunchAgent, Discord, Monitoring]
draft: true
description: "4-Tier 자가복구 시스템의 전체 통합, Level 4 알림 시스템, 그리고 실제 운영 중 얻은 노하우를 공유합니다."
---

## TL;DR

- **통합**: LaunchAgent + 크론 + 스크립트로 완전 자동화
- **Level 4**: Discord 웹훅으로 인간 호출
- **모니터링**: 메트릭 수집, 로그 로테이션
- **운영 노하우**: 삽질 기록과 교훈
- **오픈소스**: GitHub에 공개, 원클릭 설치 지원

---

## 전체 시스템 통합

### 구성 요소

```
┌─────────────────────────────────────────────────────────────┐
│                      macOS 시스템                            │
├─────────────────────────────────────────────────────────────┤
│  LaunchAgent                                                │
│  ├── ai.openclaw.watchdog (Level 1, 기존)                   │
│  └── com.openclaw.healthcheck (Level 2, 신규)               │
├─────────────────────────────────────────────────────────────┤
│  Scripts (~/openclaw/scripts/)                              │
│  ├── gateway-healthcheck.sh     (Level 2)                   │
│  ├── emergency-recovery.sh      (Level 3)                   │
│  └── emergency-recovery-monitor.sh (Level 4)                │
├─────────────────────────────────────────────────────────────┤
│  Cron (OpenClaw 내장)                                       │
│  └── Emergency Recovery Monitor (5분 간격)                   │
├─────────────────────────────────────────────────────────────┤
│  External                                                   │
│  ├── Discord Webhook (#jarvis-health)                       │
│  └── Claude Code CLI                                        │
└─────────────────────────────────────────────────────────────┘
```

### Level 2 LaunchAgent 설정

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openclaw.healthcheck</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/ramsbaby/openclaw/scripts/gateway-healthcheck.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>  <!-- 5분 간격 -->
    <key>RunAtLoad</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
```

**주의:** `PATH`에 Homebrew 경로 포함 필수 (tmux, claude 실행 위해)

---

## Level 4: Discord 알림 시스템

### 왜 Discord인가?

1. **무료** — 웹훅 무제한
2. **모바일 푸시** — 즉시 알림
3. **히스토리** — 채널에 기록 남음
4. **포맷팅** — 마크다운, 임베드 지원

### 웹훅 설정

```bash
# .env 파일
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1234567890/abcdefg..."
```

**⚠️ 절대 코드에 하드코딩하지 마세요!**

### 알림 메시지 설계

```bash
failure_msg="🚨 **Level 3 Emergency Recovery 실패!**

**모든 자동 복구 시스템이 실패했습니다:**
- Level 1 (Watchdog): ❌
- Level 2 (Health Check): ❌
- Level 3 (Claude Recovery): ❌

**수동 개입 필요**
- HTTP 상태: $http_code
- 복구 시간: ${total_time}초
- 로그: \`$LOG_FILE\`

**복구 시도:**
\`\`\`bash
openclaw status
openclaw gateway restart
\`\`\`"
```

**설계 원칙:**
- 이모지로 긴급도 표시
- 실패한 레벨 명시
- 즉시 실행 가능한 복구 명령 포함
- 로그 파일 경로 안내

---

## 메트릭 수집

### JSON Lines 포맷

```bash
record_metric() {
    local timestamp=$(date +%s)
    echo "{\"timestamp\":$timestamp,\"metric\":\"$1\",\"result\":\"$2\",\"duration\":$3}" \
        >> "$LOG_DIR/.healthcheck-metrics.json"
}
```

**수집 항목:**
- `http_check`: HTTP 응답 코드, 응답 시간
- `gateway_restart`: 성공/실패, 소요 시간
- `recovery`: 성공/실패/self_healed, 재시도 횟수
- `emergency_recovery`: 성공/실패, 총 소요 시간

### 분석 예시

```bash
# 최근 7일간 복구 성공률
cat ~/.openclaw/memory/.healthcheck-metrics.json | \
  jq -s '[.[] | select(.metric=="recovery")] | 
         group_by(.result) | 
         map({result: .[0].result, count: length})'
```

출력:
```json
[
  {"result": "success", "count": 12},
  {"result": "failed", "count": 2},
  {"result": "self_healed", "count": 3}
]
```

---

## 로그 로테이션

### 14일 보관 정책

```bash
rotate_old_logs() {
    find "$LOG_DIR" -name "healthcheck-*.log" -mtime +14 -delete
    find "$LOG_DIR" -name "emergency-recovery-*.log" -mtime +14 -delete
    find "$LOG_DIR" -name "claude-session-*.log" -mtime +14 -delete
}
```

**매 Health Check 실행 시 자동 정리**

---

## 원클릭 설치

v1.3.0부터 지원:

```bash
curl -sSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install.sh | bash
```

**자동 수행:**
1. 의존성 체크 (tmux, claude, openclaw)
2. 스크립트 다운로드 및 권한 설정
3. .env 템플릿 생성
4. LaunchAgent 설치 및 로드
5. 설치 완료 메시지

---

## 운영 노하우 (삽질 기록)

### 1. ShellCheck False Positive

**문제:** `trap cleanup EXIT`에서 cleanup 함수가 "unreachable" 경고

**해결:**
```bash
# shellcheck disable=SC2329,SC2317
cleanup() { ... }
```

### 2. 파일 생성 순서

**문제:** SESSION_LOG 생성이 디렉토리 생성보다 먼저 실행 → 에러

**해결:** `mkdir -p`를 파일 생성 전에 실행

### 3. 완료 감지 오탐

**문제:** Claude가 "done checking"이라고 하면 조기 종료

**해결:** 패턴을 더 구체적으로: `"recovery completed|gateway restored|http 200"`

### 4. /tmp 락 파일 보안

**문제:** 다른 사용자가 `/tmp/lockfile` 생성하면 DoS

**해결:** 락 파일을 사용자 전용 디렉토리로 이동

### 5. Claude 워크스페이스 신뢰

**문제:** 첫 실행 시 "Trust this workspace?" 프롬프트

**해결:** Enter 키 자동 전송
```bash
tmux send-keys -t "$SESSION" "" C-m
```

---

## 시스템 검증 체크리스트

배포 전 확인:

```bash
# 1. 스크립트 문법 검증
bash -n scripts/*.sh

# 2. ShellCheck
shellcheck scripts/*.sh

# 3. Health Check 수동 실행
./scripts/gateway-healthcheck.sh

# 4. LaunchAgent 상태
launchctl list | grep openclaw

# 5. 로그 확인
tail -f ~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log
```

---

## 한계와 향후 계획

### 현재 한계

| 한계 | 이유 | 대안 |
|------|------|------|
| macOS 전용 | LaunchAgent 사용 | Linux: systemd |
| Claude 의존 | API 할당량 소진 시 실패 | GPT-4 폴백 |
| 단일 노드 | 클러스터 미지원 | 향후 개발 |

### 로드맵

- **Phase 2**: Linux systemd 지원, GPT-4 대체
- **Phase 3**: 멀티노드, Prometheus 메트릭

---

## 마무리: "시스템이 스스로를 치료한다"

3편에 걸쳐 4-Tier 자가복구 시스템을 소개했다.

**핵심 메시지:**
1. **싼 검사부터** — 비싼 리소스(Claude)는 마지막에
2. **자율 판단** — 규칙 기반의 한계를 AI로 극복
3. **안전장치 필수** — 타임아웃, 락 파일, 권한 제한
4. **인간 호출** — 모든 자동화가 실패하면 결국 사람

GitHub에 오픈소스로 공개했다:
**https://github.com/Ramsbaby/openclaw-self-healing**

원클릭 설치:
```bash
curl -sSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install.sh | bash
```

질문이나 개선 제안은 GitHub Issues로!

---

#### 시리즈 전체 목록

1. [Part 1: AI가 AI를 치료하다](/blog/self-healing-part1) — 배경과 아키텍처
2. [Part 2: Claude Code를 응급의사로](/blog/self-healing-part2) — Level 3 구현
3. **Part 3: 시스템 통합과 운영** — 이 글

---

#### 읽어주셔서 감사합니다.🖐
