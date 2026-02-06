---
title: "OpenClaw 자가복구 시스템 Part 2 - Claude Code를 응급의사로 활용하기"
date: 2026-02-07
category: AI
tags: [OpenClaw, Claude, tmux, PTY, Automation]
draft: true
description: "tmux PTY에서 Claude Code를 실행하여 자율 진단/복구를 수행하는 Level 3 시스템의 구현 세부사항을 공유합니다."
---

## TL;DR

- **핵심**: Claude Code를 tmux PTY 세션에서 실행, 자율 진단/복구
- **구현**: bash 스크립트 ~150줄로 완성
- **트릭**: 워크스페이스 신뢰 자동 처리, 완료 감지 폴링
- **안전장치**: 30분 타임아웃, 락 파일, 권한 제한
- **결과**: 평균 복구 시간 5-10분 (최대 30분)

---

## Level 3의 핵심 아이디어

Level 2 (Health Check)가 3번 재시도해도 실패하면, 단순 재시작으로는 해결 안 되는 문제다.

이때 필요한 건:
1. **로그 분석** — 에러 메시지 확인
2. **설정 검증** — JSON 문법 오류, 포트 충돌 등
3. **의존성 체크** — Node.js 버전, npm 패키지 상태
4. **지능적 판단** — 어떤 조치를 취할지 결정

이걸 규칙 기반으로 하면? 새로운 에러 패턴마다 코드 수정 필요.
Claude에게 맡기면? **"이 로그 보고 알아서 고쳐"** 가 가능.

---

## tmux PTY가 필요한 이유

Claude Code는 단순 파이프(`echo "명령" | claude`)로는 제대로 작동 안 한다.

**이유:**
- 인터랙티브 모드 필요 (워크스페이스 신뢰 프롬프트)
- 실시간 출력 캡처
- 멀티턴 대화 지원

**해결책:** tmux PTY 세션

```bash
# PTY 세션 생성
tmux new-session -d -s "emergency_recovery_2026-02-06-1930"

# Claude 실행
tmux send-keys -t "$TMUX_SESSION" "claude" C-m

# 워크스페이스 신뢰 자동 처리
sleep 5
tmux send-keys -t "$TMUX_SESSION" "" C-m  # Enter 키

# 복구 명령 전송
tmux send-keys -t "$TMUX_SESSION" "$recovery_command" C-m
```

---

## 완료 감지: 폴링 vs 고정 대기

### 초기 구현 (비효율)

```bash
sleep 1800  # 30분 무조건 대기
```

**문제:** Claude가 5분 만에 끝나도 30분 기다림

### 개선된 구현 (폴링)

```bash
local poll_interval=30
local elapsed=0
local idle_count=0
local max_idle=6  # 3분간 변화 없으면 완료

while [ $elapsed -lt "$RECOVERY_TIMEOUT" ]; do
    sleep "$poll_interval"
    elapsed=$((elapsed + poll_interval))
    
    # 현재 출력 캡처
    current_output=$(tmux capture-pane -t "$TMUX_SESSION" -p | tail -20)
    
    # 완료 시그널 체크
    if echo "$current_output" | grep -qiE "(recovery completed|gateway restored|http 200)"; then
        break
    fi
    
    # 출력 변화 체크 (idle detection)
    if [ "$current_output" = "$last_output" ]; then
        idle_count=$((idle_count + 1))
        if [ $idle_count -ge $max_idle ]; then
            break  # 3분간 출력 없음 = 완료
        fi
    else
        idle_count=0
    fi
done
```

**결과:** 평균 복구 시간 5-10분으로 단축

---

## 안전장치 설계

### 1. 타임아웃 (30분)

Claude가 무한 루프에 빠지거나 응답 없을 때 대비

```bash
RECOVERY_TIMEOUT="${EMERGENCY_RECOVERY_TIMEOUT:-1800}"
```

### 2. 락 파일

동시 실행 방지 (Health Check가 중복 호출할 때)

```bash
# 보안 경로 (다른 사용자 접근 불가)
LOCKFILE="$LOG_DIR/.emergency-recovery.lock"

if [ -f "$LOCKFILE" ]; then
    exit 0  # 이미 실행 중
fi
touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT
```

### 3. 클린업 트랩

스크립트 종료 시 tmux 세션 정리

```bash
cleanup() {
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    rm -f "$LOCKFILE"
}
trap cleanup EXIT INT TERM
```

### 4. 로그 권한

Claude 세션 로그에 민감한 정보 포함될 수 있음

```bash
touch "$SESSION_LOG"
chmod 600 "$SESSION_LOG"
```

---

## 복구 프롬프트 설계

Claude에게 전달하는 프롬프트가 핵심이다.

```bash
recovery_command="OpenClaw 게이트웨이가 5분간 재시작했으나 복구되지 않았습니다.

작업 순서:
1. openclaw status 체크
2. 로그 분석 (~/.openclaw/logs/*.log)
3. 설정 검증 (~/.openclaw/openclaw.json)
4. 포트 충돌 체크 (lsof -i :18789)
5. 의존성 체크 (npm list, node --version)
6. 복구 시도 (설정 수정, 프로세스 재시작)
7. 결과를 $REPORT_FILE 에 기록

작업 제한시간: ${RECOVERY_TIMEOUT}초 이내
목표: Gateway가 $GATEWAY_URL 에서 HTTP 200 응답하도록 복구"
```

**설계 원칙:**
- 명확한 목표 (HTTP 200)
- 순서가 있는 작업 목록
- 타임아웃 명시
- 결과 기록 요청

---

## 실제 복구 사례

### Case 1: 설정 파일 문법 오류 (2026-02-05)

**증상:** Gateway 시작 실패, 로그에 "JSON parse error"

**Claude 진단:**
```
[분석] ~/.openclaw/openclaw.json 열어봄
[발견] 라인 47: 쉼표 누락
[조치] jq로 포맷 후 저장
[확인] openclaw gateway restart → 성공
```

### Case 2: 포트 충돌 (2026-02-06)

**증상:** "EADDRINUSE: address already in use"

**Claude 진단:**
```
[분석] lsof -i :18789
[발견] 좀비 프로세스 PID 12345
[조치] kill -9 12345
[확인] 재시작 → HTTP 200
```

---

## Trade-off: Claude API 비용

30분 세션 비용 추정:
- Input: ~2,000 tokens × $0.003/1K = $0.006
- Output: ~5,000 tokens × $0.015/1K = $0.075
- **총 비용: ~$0.08/복구**

**월간 추정:**
- 복구 2회/월 × $0.08 = **$0.16/월**

야간 수동 대응 비용 대비 **무시할 수준**.

---

## 개선 아이디어

### 1. 복구 패턴 학습

성공한 복구 로그를 수집하여 다음 복구에 참조:

```bash
# 성공 시 패턴 저장
if [ "$SUCCESS" = "true" ]; then
    cp "$SESSION_LOG" "$LOG_DIR/successful-recoveries/"
fi
```

### 2. 다른 LLM 지원

Claude 할당량 소진 시 GPT-4 또는 Gemini로 폴백:

```bash
if ! check_claude_quota; then
    LLM_COMMAND="openai-cli"  # 또는 gemini
fi
```

### 3. Slack/Telegram 알림

Discord 외 다른 채널 지원

---

## 마무리

Level 3 Claude Doctor는 **"규칙으로 정의할 수 없는 장애"**를 처리한다.

핵심 포인트:
1. tmux PTY로 인터랙티브 세션 제공
2. 폴링으로 조기 완료 감지
3. 안전장치로 무한 루프 방지
4. 명확한 프롬프트로 목표 전달

**다음 편 예고:** Level 4 Discord 알림과 전체 시스템 통합

---

#### 읽어주셔서 감사합니다.🖐
