# Archived from MEMORY.md (2026-02-09)

## 🔬 Benchmarking & AI Agent Evolution (2026-02-07)

### ClawHub 신규 스킬 (발견)

**Agent Orchestrator** by aatmaan1
- 복잡한 작업을 subtasks로 자동 분해
- Sub-agents 동적 생성
- **적용 아이디어:** 자비스 sessions_spawn 전략 고도화

**Capability Evolver** by autogame-17
- 런타임 기록으로 자체 진화 (protocol-constrained)
- **적용 아이디어:** Self-Healing System v2.0에 반영

**self-improving-agent** by pskoett
- 실패와 수정 기록으로 지속적 학습
- **적용 아이디어:** Memory flush 자동화 + 근본 원인 분석

### 🔴 보안 경고 & 발견

**ClawHavoc Campaign (Koi Security)**
- 341개 악성 ClawHub 스킬 발견
- 역쉘 백도어, credential exfiltration, 가짜 AuthTool
- **해결:** Clawdex 보안 도구로 설치 전 검증

**Moltbook DB Breach (3일 전)**
- 모든 AI agent 제어 가능하도록 노출
- **학점:** API 보안이 생명

### 💡 GitHub Trending 벤치마크

**Claude Code Memory Capture Plugin** (8,130⭐/week)
- 모든 Claude 작업 자동 기록 → AI 압축 → 미래 세션 주입
- ✅ **자비스도 동일:** MEMORY.md + memory/*.md + SESSION-STATE.md
- **개선:** 세션 종료 전 자동 플러시 (current status: manual WAL)

**Dify** (14,168⭐/week)
- Agentic workflows를 위한 production-ready 플랫폼
- **적용:** 자비스의 cron + sessions_spawn 구조화

**TypeScript Dominance**
- Python 넘어섬 (2025년 8월부터)
- **정리:** 자비스 스킬 개발 시 TS/Node.js 우선

### 🎯 즉시 적용 개선 (HIGH PRIORITY)

1. **Skill Security Scanning** (Medium difficulty)
2. **Context Window Auto-Flush** (Easy)
3. **Memory Capture Automation** (Medium)
4. **Sub-task Auto-Decomposition** (Hard)

### 📚 연구 과제 (RESEARCH)

- **Minimal Agent (NanoClaw):** 500줄 TS에서 Core 기능만
- **Agent Autonomy Index:** 정우님 개입 없이 자비스 독립성 측정
- **Moltbook Integration:** 자비스가 다른 agents와 상호작용
- **Self-Evolution Framework:** Failure → Pattern Learning → Auto-improve
- **Waymo-style World Model:** 정우님 환경의 동적 세계 모델 구축

### 📊 Hacker News Insights (2026-02-07)

**Top Stories:**
1. Waymo World Model (685 pts)
2. Microsoft LiteBox (289 pts)
3. Show HN: Vecti (212 pts)

### 🧠 Reddit Community Signals (r/programming)

**주요 합의:**
- LLM 코딩은 빠르지만 "증명과 검증"이 모든 일
- 소프트웨어 엔지니어는 절대 LLM으로 대체 불가
- AI가 B2B SaaS를 죽이지 못하는 이유 = 검증의 어려움
## Command Shortcuts

### "자비스정보탐험" 트리거
정우님이 이 키워드를 입력하면 자동 실행:

**1. ClawHub 탐색**
- 명령어: `clawhub search "AI automation productivity" --limit=10`
- 우선순위: AI, automation, productivity, developer-tools
- 체크: 새 스킬, 업데이트된 스킬, trending 스킬

**2. Moltbook 동향**
- 최근 24시간 핫 포스트
- 새로운 AI 에이전트 공유
- 유용한 스킬/도구 언급
- 커뮤니티 이슈/트렌드

**3. GitHub Trending**
- Today + This Week 탑 repos
- 언어 필터: JavaScript, TypeScript, Python, Go, Rust
- 주목: AI/ML, automation, CLI tools, developer productivity

**4. Hacker News**
- Top 10 stories (front page)
- "Show HN" 필터링 (새 프로젝트)
- "Ask HN" 중 기술 질문
- 키워드: AI, automation, productivity, tools

**5. Reddit 탐색**
- Subreddits: r/programming, r/coding, r/MachineLearning, r/artificial, r/SideProject
- 필터: Hot posts (24시간 이내)
- 관심사: AI agents, automation tools, developer workflows

**6. 정우님 GitHub**
- ramsbaby repos 새 이슈
- 멘션/댓글 알림
- PR 상태 체크

**결과 포맷:**
```
🎯 자비스 정보 탐험 결과

## 🦅 ClawHub
- [스킬명] - 설명
- ...

## 🤖 Moltbook
- [포스트 제목] - 핵심 내용
- ...

## 💎 GitHub Trending
- [Repo] - 설명 + 스타 수
- ...

## 🔥 Hacker News
- [제목] - 포인트 + 댓글 수
- ...

## 📱 Reddit
- [r/subreddit] 제목 - 핵심
- ...

## 🚨 정우님 GitHub
- [repo] 새 이슈/멘션
- ...

## 🎯 벤치마킹 & 자비스 개선 아이디어
각 소스에서 발견한 것 중 자비스에 적용 가능한 것들:
- [출처] 아이디어 → 자비스 적용 방안
- 우선순위: High/Medium/Low
- 구현 난이도: Easy/Medium/Hard
- ...
```

**실행 빈도:**
- 수동: "자비스정보탐험" 입력 시
- 선택적 크론: 매일 오전 10시 (필요 시 설정)

---

## Frequently Used Commands

### Claude Usage Check
1. `claude` PTY 실행
2. 워크스페이스 신뢰 확인 (Enter)
3. `/usage` 입력
4. Escape + 종료

---

---
## 🔬 Benchmarking & AI Agent Evolution (2026-02-07)

### ClawHub 신규 스킬 (발견)

**Agent Orchestrator** by aatmaan1
- 복잡한 작업을 subtasks로 자동 분해
- Sub-agents 동적 생성
- **적용 아이디어:** 자비스 sessions_spawn 전략 고도화

**Capability Evolver** by autogame-17
- 런타임 기록으로 자체 진화 (protocol-constrained)
- **적용 아이디어:** Self-Healing System v2.0에 반영

**self-improving-agent** by pskoett
- 실패와 수정 기록으로 지속적 학습
- **적용 아이디어:** Memory flush 자동화 + 근본 원인 분석

### 🔴 보안 경고 & 발견

**ClawHavoc Campaign (Koi Security)**
- 341개 악성 ClawHub 스킬 발견
- 역쉘 백도어, credential exfiltration, 가짜 AuthTool
- **해결:** Clawdex 보안 도구로 설치 전 검증
- **행동:** 자비스 스킬 설치 정책 강화 필수

**Moltbook DB Breach (3일 전)**
- 모든 AI agent 제어 가능하도록 노출
- **학점:** API 보안이 생명

### 💡 GitHub Trending 벤치마크

**Claude Code Memory Capture Plugin** (8,130⭐/week)
- 모든 Claude 작업 자동 기록 → AI 압축 → 미래 세션 주입
- ✅ **자비스도 동일:** MEMORY.md + memory/*.md + SESSION-STATE.md
- **개선:** 세션 종료 전 자동 플러시 (current status: manual WAL)

**Dify** (14,168⭐/week)
- Agentic workflows를 위한 production-ready 플랫폼
- **적용:** 자비스의 cron + sessions_spawn 구조화

**TypeScript Dominance**
- Python 넘어섬 (2025년 8월부터)
- **정리:** 자비스 스킬 개발 시 TS/Node.js 우선

### 🎯 즉시 적용 개선 (HIGH PRIORITY)

1. **Skill Security Scanning** (Medium difficulty)
   - Action: Clawdex 통합 → skill install 전 자동 검증
   - Timeline: This week

2. **Context Window Auto-Flush** (Easy)
   - Action: 70%+ 사용 시 자동 플러시 + 요약
   - Timeline: Immediate

3. **Memory Capture Automation** (Medium)
   - Action: SESSION-STATE 플러시 전 전체 기록 자동화
   - Timeline: This week

4. **Sub-task Auto-Decomposition** (Hard)
   - Action: 복잡한 작업 감지 → 전문화된 sub-agents 자동 할당
   - Timeline: Next week

### 📚 연구 과제 (RESEARCH)

- **Minimal Agent (NanoClaw):** 500줄 TS에서 Core 기능만 (실험 가치)
- **Agent Autonomy Index:** 정우님 개입 없이 자비스 독립성 측정
- **Moltbook Integration:** 자비스가 다른 agents와 상호작용할 수 있을까?
- **Self-Evolution Framework:** Failure → Pattern Learning → Auto-improve
- **Waymo-style World Model:** 정우님 환경의 동적 세계 모델 구축

### 📊 Hacker News Insights (2026-02-07)

**Top Stories:**
1. Waymo World Model (685 pts) - Attention mechanism in autonomous systems
2. Microsoft LiteBox (289 pts) - Security-focused library OS
3. Show HN: Vecti (212 pts) - "Features I actually use" philosophy

**정우님 철학과의 일치:**
- "필요한 것만" 원칙 (Vecti 개발자와 동일)
- 극도로 최소화된 구현 (NanoClaw: 500줄)

### 🧠 Reddit Community Signals (r/programming)

**주요 합의:**
- LLM 코딩은 빠르지만 "증명과 검증"이 모든 일 (현실)
- 소프트웨어 엔지니어는 절대 LLM으로 대체 불가 (마지막 20%가 가장 어려움)
- AI가 B2B SaaS를 죽이지 못하는 이유 = 검증의 어려움

**자비스 적용:**
- 겸손하게, 확신 말고 확인으로
- 최종 검증은 정우님의 몫 (무조건)

---


---
# Archived Important Decisions (2026-02-09)

### 2026-02-07: 자기평가 V5.0.1 AOP 리팩토링 🎯
- **문제:** V5.0 → V5.0.2 업그레이드 시 33개 크론 전부 수정 필요 (노가다)
- **해결:** 횡단지향적(AOP) 패턴 도입 → 공통 라이브러리 방식
- **구조:**
  - **공통 lib:** `~/openclaw/lib/self-review-lib.sh` (v5.0.1)
  - **함수:** `sr_log_review()` — 자기평가 로직 집중화
  - **적용 대상:** 4개 Bash 스크립트 (emergency-recovery-monitor, daily-backup, morning-briefing, evening-briefing)
  - **나머지 29개:** 크론 메시지 기반 (기존 유지)
- **변경 사항:**
  - 각 스크립트에 `source ~/openclaw/lib/self-review-lib.sh` 추가 (1줄)
  - `sr_log_review()` 함수 호출로 자기평가 (1줄)
  - main 함수 내 `exit` → `return` 변경 (exit code 전파)
- **효과:**
  - **Before:** V5.0.2 업그레이드 → 33개 스크립트/크론 수정
  - **After:** V5.0.2 업그레이드 → **lib 1개만 수정** (4개 자동 반영)
  - **노가다 축소:** 33 → 1
- **안전장치:**
  - 방어적 코드: 자기평가 실패해도 크론 계속 실행
  - 네임스페이스 prefix (`sr_`) — 함수명 충돌 방지
  - 상대 경로 사용 — 환경 의존성 최소화
- **검증:**
  - ✅ Emergency Recovery Monitor: 정상 작동
  - ✅ Daily Backup: 정상 작동
  - ✅ lib source: 정상 (v5.0.1 로드 확인)
  - ✅ 자기평가 로깅: YAML 파일 생성 확인
- **교훈:**
  - 의존성을 중앙화하면 유지보수 비용이 극적으로 감소
  - 레거시 템플릿 (`cron-persona.txt`) 제거로 혼란 방지
  - 점진적 마이그레이션 (4개 스크립트) → 안정성 확보
- **다음 버전 업그레이드 시:** `vim ~/openclaw/lib/self-review-lib.sh` → 끝.

### 2026-02-07: 자기평가 V5.0 도입 🎉
- **V4.0 → V5.0 업그레이드** (정우님 요청: "비판적 시각으로 재설계")
- **V5.0 핵심 변경**:
  - **Layer 1:** 자동 메트릭 수집 (duration, tokens만 - 측정 가능한 것만)
  - **Layer 2:** LLM 자기성찰 + **bias_check** (편향 인정 필수)
  - **Layer 3:** 외부 검증 (주간 Opus 리뷰, ~$0.60/월)
  - **Layer 4:** PDCA 사이클 통합
- **업계 베스트 프랙티스 반영**:
  - Microsoft Azure 5 Pillars (Metrics, Logs, Traces, Evaluations, Governance)
  - LLM-as-a-Judge 편향 연구 (Self-enhancement bias 인정)
  - OpenTelemetry semantic conventions
- **파일 구조**:
  - 템플릿: `~/openclaw/templates/self-review-v5.0.yaml`
  - 스크립트: `~/openclaw/scripts/self-review-logger.sh`
  - 문서: `~/openclaw/docs/self-review-v5.0.md`
  - 저장: `~/openclaw/memory/self-review/YYYY-MM-DD/`
- **주간 검증 크론**: `6b9054f4-8afb-4c56-a875-8648a661653a` (Opus)
- **마이그레이션**: Week 1~5 로드맵 진행 중

### 2026-02-03
- OpenClaw로 마이그레이션 완료 (clawdbot → openclaw)
- Watchdog 시스템 설정 (LaunchAgent, 180초 간격)
- 보안 설정 강화 (elevated allowlist 제한, CRITICAL 0)
- 설정 오류 수정: `alsoAllow`→`allow`, `exec.ask`→`on-miss`, `tools.allow` 정리
- 세션 관리: idleMinutes 7일, memoryFlush 활성화
- 크론 22개 (Haiku 모델, Daily Backup/Log Rotation/Monthly Update 추가)
- **Telegram Webhook 전환**: Long-polling → Webhook (AbortError 해결)
- Tailscale Funnel 활성화 (공개 URL 제공)
- 메모리 파일 통합: ~/clawd/memory → ~/openclaw/memory
- Gemini 설정 정리 (사용 종료)
- KeepAlive 수정 (재부팅 블록 문제 해결)
- **Response Guard 플러그인 삭제**: 커뮤니티 검증 결과 SOUL.md/AGENTS.md가 자동 주입됨. 플러그인은 보안/sanitization 전용 (before_tool_call, after_tool_call). message_sending 훅 응답 품질 검증 사례 전무. 중복 제거로 600-800 tokens/session 절감.

---

## Notes

- Memory files: `memory/YYYY-MM-DD.md` (daily logs)
- This file: Long-term curated facts
- "If you say 'remember this', write it here"
