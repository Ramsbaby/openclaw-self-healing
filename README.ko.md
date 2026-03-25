<div align="center">

# OpenClaw 자가복구 시스템

### *모든 서비스를 위한 자율 AI 기반 복구*

**새벽 3시에 알림 받는 일 그만하세요. AI가 크래시를 자동으로 고치게 하세요.**

[![Version](https://img.shields.io/badge/version-3.4.0-blue.svg)](https://github.com/Ramsbaby/openclaw-self-healing/releases)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Docker-blue.svg)](#-빠른-시작)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/ramsbaby/openclaw-self-healing?style=social)](https://github.com/ramsbaby/openclaw-self-healing/stargazers)
[![Recovery Rate](https://img.shields.io/badge/자율_복구율-64%25-brightgreen)](README.md)
[![LLM-Agnostic](https://img.shields.io/badge/AI-Claude%20%7C%20GPT--4%20%7C%20Gemini%20%7C%20Ollama-blueviolet)](README.md)
[![Prometheus](https://img.shields.io/badge/metrics-Prometheus%20%2F%20Grafana-orange)](README.md)
[![Lint](https://github.com/Ramsbaby/openclaw-self-healing/actions/workflows/lint.yml/badge.svg)](https://github.com/Ramsbaby/openclaw-self-healing/actions/workflows/lint.yml)

[🚀 빠른 시작](#-빠른-시작) · [🎬 데모](#-데모) · [🏗️ 아키텍처](#️-아키텍처) · [📖 문서](docs/)

</div>

<p align="center">
  <img src="docs/assets/hero.svg" alt="openclaw-self-healing" width="100%">
</p>

> 이 시스템이 당신의 밤을 구했다면 🌙 ⭐ 하나가 다른 사람들이 찾는 데 큰 힘이 됩니다.

---

## 🎬 데모

<div align="center">

![Self-Healing Demo](https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/assets/demo.gif)

*4계층 복구 실제 동작: KeepAlive → Watchdog → AI Doctor → Alert*

</div>

---

## 왜 만들었나요?

> **이 시스템은 모든 장기 실행 서비스에 자율 크래시 복구를 씌웁니다.** OpenClaw Gateway가 주요 예시지만, watchdog/복구 아키텍처는 어떤 서비스에도 적용할 수 있습니다.

자정에 서비스가 크래시됩니다. 기본 watchdog이 재시작합니다 — 그런데 설정 파일이 손상됐다면? API 레이트 리밋에 걸렸다면? 의존성이 깨졌다면?

**단순 재시작 = 크래시 루프.** 알림이 옵니다. 주말이 날아갑니다.

**이 시스템은 재시작만 하지 않습니다 — 근본 원인을 이해하고 고칩니다.**

---

## 기본 Watchdog과 비교

| 기능 | 기본 Watchdog | supervisord | openclaw-self-healing |
|------|--------------|-------------|----------------------|
| 크래시 시 자동 재시작 | ✅ | ✅ | ✅ |
| HTTP 헬스 폴링 | ❌ | ❌ | ✅ |
| 크래시 루프 방지 (백오프) | ❌ | 부분 | ✅ 지수 백오프 |
| 시작 전 설정 유효성 검사 | ❌ | ❌ | ✅ Level 0 Preflight |
| **AI 근본 원인 진단** | ❌ | ❌ | ✅ Claude / GPT-4 / Gemini / Ollama |
| **손상된 설정 자동 수정** | ❌ | ❌ | ✅ |
| 멀티채널 알림 (Discord/Slack/Telegram) | ❌ | ❌ | ✅ |
| Prometheus 메트릭 | ❌ | ❌ | ✅ |
| macOS + Linux + Docker | 부분 | ✅ | ✅ |
| 벤더 락인 없음 | ✅ | ✅ | ✅ MIT |

핵심 차이: 재시작만으로 해결할 수 없는 크래시 루프에서 다른 모든 도구는 사람에게 알림을 보냅니다. 이 시스템은 먼저 고치려고 시도합니다.

---

## 먼저 체험해보기 (드라이런)

커밋하기 전에 설치 프로그램이 정확히 무엇을 할지 미리 확인하세요 — 변경 없음:

```bash
curl -fsSL https://raw.githubusercontent.com/Ramsbaby/openclaw-self-healing/main/install.sh | bash -s -- --dry-run
```

---

## 🚀 빠른 시작

### 사전 요구사항

- **macOS 12+** 또는 **Linux** (Ubuntu 20.04+ / systemd) 또는 **Docker**
- **[OpenClaw Gateway](https://github.com/openclaw/openclaw)** 설치 및 실행 중
- **모든 주요 LLM** — Claude CLI (기본), OpenAI, Gemini, Ollama. [LLM 무관 지원](#-llm-무관-복구-v33-신규) 참고
- `tmux`, `jq` (`brew install tmux jq` 또는 `apt install tmux jq`)

> **참고:** OpenClaw Gateway를 위해 만들어졌지만, watchdog/복구 아키텍처는 **모든 서비스**에 적용할 수 있습니다. 적용 방법은 [docs/configuration.md](docs/configuration.md) 참고.

### Option 1: 원라인 설치 (macOS / Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/ramsbaby/openclaw-self-healing/main/install.sh | bash
```

### Option 2: Docker Compose

```bash
git clone https://github.com/Ramsbaby/openclaw-self-healing.git
cd openclaw-self-healing
cp .env.example .env   # 설정 편집
docker compose up -d
```

### 작동 확인

```bash
# Gateway를 강제 종료해서 자동 복구 테스트
kill -9 $(pgrep -f openclaw-gateway)

# ~30초 후 확인
curl http://localhost:18789/
# 예상 결과: HTTP 200 ✅
```

---

## 작동 방식

### 5계층 자율 복구

| 계층 | 내용 | 트리거 | 방법 |
|------|------|--------|------|
| **0** | Preflight 검증 | 매 콜드스타트 | 실행 전 바이너리, .env 키, JSON 설정 유효성 검사 |
| **1** | LaunchAgent KeepAlive | 모든 크래시 | 즉시 재시작 (0–30초) |
| **2** | Watchdog v4.1 + HealthCheck | 반복 크래시 | PID + HTTP + 메모리 모니터링, 지수 백오프 |
| **3** | AI 긴급 복구 | 30분 연속 실패 | PTY 세션 → 로그 분석 → 자동 수정 (Claude/GPT-4/Gemini/Ollama) |
| **4** | 사람 알림 | 모든 자동화 실패 | Discord/Slack/Telegram + 전체 컨텍스트 |

**Level 0 (v3.2 신규):** 설정 손상, .env 키 누락, JSON 파싱 오류를 Gateway 시작 전에 감지 — 잘못된 설정으로 인한 크래시 루프를 원천 차단합니다.

---

## 실제 프로덕션 수치

14건의 실제 인시던트 감사 (2026년 2월):

| 시나리오 | 결과 |
|---------|------|
| 연속 크래시 17회 | ✅ Level 1으로 완전 복구 |
| 설정 손상 | ✅ ~3분 내 자동 수정 |
| 모든 서비스 강제 종료 | ✅ ~3분 내 복구 |
| 크래시 루프 38회+ | ⛔ 설계에 따라 중단 (무한 루프 방지) |

**14건 중 9건이 완전 자율 복구.** 나머지 5건은 Level 4로 올바르게 에스컬레이션 — 시스템이 설계대로 동작했습니다.

---

## 🏗️ 아키텍처

<p align="center">
  <img src="docs/assets/architecture.svg" alt="4계층 복구 아키텍처" width="100%">
</p>

```
Level 0: Preflight (매 콜드스타트)
│  실행 전 바이너리, .env 키, JSON 설정 유효성 검사
│  실패 시: AI 복구 세션 (tmux) + 지수 백오프
│
▼  통과
Level 1: KeepAlive (0-30초)
│  모든 크래시에서 즉시 재시작
│  ai.openclaw.gateway.plist 내장
│
▼  반복 실패
Level 2: Watchdog v4.1 (3-5분)
│  3분마다 HTTP + PID + 메모리 모니터링
│  지수 백오프: 10초 → 30초 → 90초 → 180초 → 600초
│  크래시 카운터 6시간 후 자동 감소
│
▼  30분 연속 실패
Level 3: AI 긴급 복구 (5-30분)
│  자동 트리거 — 수동 개입 불필요
│  Claude, GPT-4, Gemini, Ollama 지원
│  PTY 세션: 로그 읽기 → 진단 → 수정
│  향후 인시던트를 위한 학습 문서화
│
▼  모든 자동화 실패
Level 4: 사람 알림
   Discord/Slack/Telegram 알림 + 전체 컨텍스트
   로그 경로 + 복구 리포트 첨부
```

### 멀티채널 알림

Discord, Slack, Telegram을 지원하는 통합 알림 라이브러리 — 설정 하나, 모든 채널.

```bash
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
TELEGRAM_BOT_TOKEN="..."  # + TELEGRAM_CHAT_ID
```

---

## 🤖 LLM 무관 복구 (v3.3 신규)

Level 3 긴급 복구는 이제 Claude 전용이 아닙니다. `.env`에서 `OPENCLAW_LLM_PROVIDER` 설정:

| 프로바이더 | 설정 | 기본 모델 | 필요 조건 |
|-----------|------|----------|----------|
| **Claude** (기본) | `OPENCLAW_LLM_PROVIDER=claude` | Claude Code CLI | Claude Max 구독 |
| **OpenAI** | `OPENCLAW_LLM_PROVIDER=openai` | `gpt-4o` | `OPENAI_API_KEY` + `pip install openai` |
| **Google Gemini** | `OPENCLAW_LLM_PROVIDER=gemini` | `gemini-2.0-flash` | `GOOGLE_API_KEY` + `pip install google-generativeai` |
| **Ollama** (로컬/오프라인) | `OPENCLAW_LLM_PROVIDER=ollama` | `llama3.2` | Ollama 로컬 실행 중 |

```bash
# GPT-4o로 전환
echo 'OPENCLAW_LLM_PROVIDER=openai' >> ~/.openclaw/.env
echo 'OPENAI_API_KEY=sk-...'        >> ~/.openclaw/.env

# Ollama로 완전 오프라인 (API 키 불필요)
echo 'OPENCLAW_LLM_PROVIDER=ollama' >> ~/.openclaw/.env
echo 'OPENCLAW_LLM_MODEL=llama3.2'  >> ~/.openclaw/.env
```

---

## Prometheus 메트릭 (v3.3 신규)

Grafana 대시보드와 알림 규칙을 위한 실시간 복구 메트릭 노출.

```bash
# 익스포터 시작 (기본 포트: 9090)
bash scripts/start-metrics-exporter.sh start

# 확인
curl -s http://localhost:9090/metrics
```

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'openclaw'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 30s
```

---

## 주간 인시던트 다이제스트

```bash
# 터미널 출력
bash scripts/incident-digest.sh

# Discord 전송
bash scripts/incident-digest.sh --discord
```

---

## 로드맵

**✅ 완료:** 4계층 아키텍처 · Claude AI 연동 · `install.sh` 자동화 · Linux systemd · Level 2→3 자동 에스컬레이션 · Discord/Telegram 알림 · Preflight 검증 (v3.2) · **LLM 무관 레이어 — Claude, GPT-4, Gemini, Ollama (v3.3)** · **Prometheus 메트릭 익스포터 (v3.3)** · **멀티채널 알림 — Discord/Slack/Telegram (v3.4)** · **Docker Compose 지원 (v3.4)** · **`--dry-run` 데모 모드** · **주간 인시던트 다이제스트**

**🚧 다음:** Grafana 대시보드 템플릿 · 멀티노드 클러스터

**🔮 미래:** Kubernetes Operator

---

## OpenClaw 생태계

| 프로젝트 | 역할 |
|---------|------|
| **[openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)** ← 현재 위치 | 4계층 자율 크래시 복구 |
| **[openclaw-memorybox](https://github.com/Ramsbaby/openclaw-memorybox)** | 메모리 위생 CLI — 크래시 유발 비대화 방지 |
| **[openclaw-self-evolving](https://github.com/Ramsbaby/openclaw-self-evolving)** | AGENTS.md 개선안을 스스로 제안하는 AI 에이전트 |
| **[jarvis](https://github.com/Ramsbaby/jarvis)** | Claude Max를 사용하는 24/7 AI 운영 시스템 |

전부 MIT 라이선스, 전부 동일한 24/7 프로덕션 인스턴스에서 검증됨.

---

## 기여하기

버그 리포트, 기능 요청, 문서 개선 환영. [기여 가이드 →](CONTRIBUTING.md)

---

<div align="center">

**MIT License** · Made with 🦞 by [@ramsbaby](https://github.com/ramsbaby)

*"최고의 시스템은 망가진 것을 당신이 알아채기 전에 스스로 고치는 시스템입니다."*

[English README →](README.md)

</div>
