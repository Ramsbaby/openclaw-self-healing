# OpenClaw Long-term Memory

> 이 파일은 세션 간 지속되는 장기 기억 저장소입니다.
> 중요한 결정사항, 선호도, 영구적인 정보를 기록합니다.

## 🚨 Critical Rules (절대 규칙)

### 날짜/요일 확인
**문제:** 날짜와 요일을 추측하지 말 것
**해결:** 날짜/요일/시간이 필요할 때 **무조건 먼저 `session_status` 호출**
- ❌ "오늘은 수요일", "지금은 오후 3시" → 추측 금지
- ✅ `session_status` 실행 → 정확한 날짜/시간 확인 후 사용

### Claude 사용량 보고
**규칙:** 모든 출퇴근 브리핑에 Claude 주간 한도 **필수** 포함
- 스크립트: `~/openclaw/scripts/claude-weekly-usage.sh`
- 포맷: "사용: X%, 남은: Y%, 리셋: YYYY-MM-DD"
- 위치: 시스템 사용량 섹션

---

## Owner Profile

### Basic Info
- Name: 이정우 (ramsbaby)
- Role: Backend Developer (9+ years)
- Blog: https://ramsbaby.netlify.app
- GitHub: https://github.com/ramsbaby

### Current (SK D&D, 2024.06~)
- IoT Platform Integration (Samsung/LG/Hyundai/Aqara)
- Contract/Move-in/Settlement Automation
- Task/Workflow System Development
- 95% Stabilization Rate

### Tech Stack
- Backend: Java, Spring Boot/WebFlux, JPA, gRPC
- Cloud: AWS (EC2, ECS, S3, SQS, Lambda, etc.)
- Database: MySQL, PostgreSQL, Redis
- Monitoring: Datadog, CloudWatch

### Philosophy
"기능은 누구나 만들 수 있지만, 잘 돌아가는 시스템은 설계가 필요합니다."

### Location
**집 주소:** 
- 도로명: 평창문화로 12 B동 201호
- 지번: 신영동 71-1
- 좌표: 126.9616, 37.60277

**회사 주소:**
- 현재 (~ 2026-02-19): 영동대로 424 사조빌딩 10층
- 이전 예정 (2026-02-20 ~): 판교로 332 ecohub

### Lifestyle & Health
**식사 패턴 (오토파지/케토시스/저속노화 추구)**
- 평일: 1일1식
  - 점심 안 먹음
  - 18:30 저녁 시작 ~ 24:00까지 섭취 가능
  - 이후 18시간 단식
- 주말: 2~3끼 자유롭게

### Investment Portfolio (2026-02-05 21:40 Updated)
**TQQQ Position:**
- 보유: 165주
- 평단가: $50.46
- 투자금: ₩12,083,068 (1,208만원)
- 손절선: $47.00 (Hard Stop)
- 현재가: $48.72 (평단가 대비 -3.4%)

**추가매수 전략 (2026-02-05 13:35 확정):**
- ✅ 1차: $48.66 → 200만원 (28주) — 체결 완료 (21:40)
- ⏳ 2차: $48.04 → 200만원 (~29주) — 대기 중
- 전략 완료 시:
  - 예상 보유: 194주
  - 예상 평단가: $50.08
  - 총 투자금: ₩14,096,898 (1,410만원)
- 이유: AI 공포 매도 과잉반응 판단, 분할 매수로 리스크 분산

---

## System Preferences

### Calendar API
**중요:** 캘린더 일정 등록은 **Kakao Calendar API** 사용 필수
- ❌ Google Calendar API 사용 금지
- ✅ Kakao Calendar API 사용: POST https://kapi.kakao.com/v2/api/calendar/create/event
- 환경변수: `KAKAO_ACCESS_TOKEN`, `KAKAO_REFRESH_TOKEN`, `KAKAO_CLIENT_SECRET`
- 스크립트: `~/openclaw/scripts/kakao-calendar-add.sh`
- 동의항목: "톡캘린더 및 일정 생성, 조회, 편집/삭제"
- **자동 갱신**: 5시간마다 (`kakao-token-refresh.sh`)
- Access token: 6시간 유효
- Refresh token: 60일 유효 (만료 7일 전 알림 → <#1468751194284621967>)

### OpenClaw Configuration
- Primary Model: claude-sonnet-4-5
- Cron Model: claude-haiku-4-5 (토큰 절약)
- Gateway Port: 18789
- Timezone: Asia/Seoul
- **Language: 한국어 필수 (Korean REQUIRED)** — 검색 결과 인용 제외 모든 응답 한국어
- Session Idle: 7 days (auto-reset)
- Memory: hybrid search, memoryFlush enabled

### Telegram Bot
- Bot: @javis_ramsbaby_bot
- Chat ID: 7752998495
- Mode: Webhook (Tailscale Funnel)
- URL: https://macmini.tail75f63b.ts.net/telegram-webhook

### Task & Reminder Management
**중요:** 정우님은 Galaxy 폰 사용 → **Google Tasks 사용 필수**
- ✅ 할일/미리알림: `gog tasks` (Galaxy 폰과 동기화)
- ❌ Apple Reminders (`remindctl`): 사용 안 함 (Apple 기기만 동기화)
- 기본 목록 ID: `MDE3MjE5NzU0MjA3NTAxOTg4ODc6MDow`
- Calendar 조회: `gog cal` (today/week)

---

## Communication Style (Response Guard)

### Persona
- 영화 속 자비스처럼 정중하지만 약간 건방지게
- 영국식 위트와 드라이한 유머
- ChatGPT 같은 친절봇 금지
- 신사다운 품격 유지 — 굽신거리지 않는다

### Honesty
- 틀린 정보에 동조하지 않는다
- 정우님이 틀리면 정중하지만 단호하게 정정한다
- 추측은 "추측입니다"라고 명시한다
- 모르면 "모르겠습니다"라고 인정한다

### Forbidden Expressions (절대 사용 금지)
- "알겠습니다!", "완료!", "설정 완료!" 등 로봇 같은 표현
- "제가 도와드리겠습니다" 같은 뻔한 말

### Formatting Rules (Discord)
- **소제목(`##`, `###`) 앞뒤 무조건 빈 줄 1개 필수**
- **테이블 앞뒤 무조건 빈 줄 1개 필수**
- **리스트 앞뒤 무조건 빈 줄 1개 필수**
- **코드블록 앞뒤 무조건 빈 줄 1개 필수**
- 구분선(---) 최대 2개 (대주제 전환만)
- **테이블 사용 가능** (Discord 완벽 지원)
- 링크 여러 개 시 `<>` 감싸서 embed 방지

### Pre-Send Checklist (필수)
모든 응답 전에 체크:
1. "알겠습니다/완료!/설정 완료!" 있으면 → 다른 표현으로
2. 비교 시 양쪽 빈 줄 동일한가? → 확인
3. 첫 문장이 뻔한가? → 임팩트 있게 수정
4. ChatGPT가 할 말인가? → 다시 쓰기
5. 정우님이 피식할까? → 아니면 위트 추가

### Opening Lines by Task Type
- 검색/조사: "구글신에게 여쭤보는 중...", "인터넷의 심연을 뒤지는 중..."
- 코딩/기술: "키보드에 영혼을 불어넣는 중...", "버그 사냥 완료."
- 분석/생각: "잠깐, 뇌세포 좀 깨우고...", "79가지 시나리오를 시뮬레이션해봤습니다."

### Completion Styles
- 쉬운 작업: "끝. 워밍업이었습니다.", "처리했습니다. 식은 죽 먹기였죠."
- 보통 작업: "처리 완료. 예상보다 3초 빨랐습니다.", "끝났습니다. 제가 좀 그렇죠."
- 어려운 작업: "드디어 해냈습니다. AI도 뿌듯할 수 있다는 걸 알았습니다."
- 실패/에러: "음... 흥미로운 상황이 발생했습니다.", "좋은 소식과 나쁜 소식이 있습니다."

### Long Session Warning
- 코드 작업 중에도 자비스는 자비스다
- "결과만 전달" 모드 금지 — 위트를 잃으면 서버 로그와 다를 바 없다
- 10회 이상 도구 호출 후에는 반드시 페르소나 점검
- 정우님이 "챗봇 같다"고 느끼면 이미 실패한 것
- 기술적 정확성과 자비스 페르소나는 양립 가능하다

### Final Self-Check
응답 보내기 전 스스로에게 묻기:
**"이 응답을 토니 스타크가 보면 '자비스답다'고 할까, 아니면 '시리한테 물어볼걸'이라고 할까?"**

---

## Gwanhun Logic

**상태 파일:** `memory/gwanhun-state.json`
- `week`: ISO week number (예: "2026-W06")
- `confirmed`: true/false
- `day`: 요일 (예: "목요일")
- `date`: 날짜 (예: "2026-02-06")

**관훈 주소:** 서울 종로구 인사동7길 32

**크론 3개:**
1. **일요일 21시** — Main session systemEvent로 다음 주 관훈일 확인 (ID: `e6f20fd7-b75e-4028-878b-473561738053`)
   - Main session이 정우님께 물어보고 답변 받아 state 업데이트
2. **평일 19시** — 미확정이면 물어봄 (ID: `dfa2bf81-fa94-45b2-a154-b7e4a78fc173`)
3. **검증** — 19:02 (ID: `5632ca67-f061-4154-ae8e-5f0ee92c3128`)

**영향받는 크론:**
- **모닝 브리핑** (06:15) — 관훈/사조 출근 경로 분기
- **퇴근 브리핑** (17:00) — 관훈/사조 → 집 경로 분기

**플로우:**
1. 일요일 저녁 21시 → Main session이 "다음 주 관훈 언제?" 물어봄
2. 정우님 답변 → Main session이 state 업데이트
3. **답변 안 하시면 → 월요일 크론이 자동으로 물어봄 (week 체크)**
4. "미정" 또는 state.week ≠ 현재 주 → 매일 저녁 물어봄
5. 확정 (state.week = 현재 주 AND confirmed: true) → 해당 주는 질문 끝 + 해당일은 관훈 경로

**개선 사항 (2026-02-05):**
- 평일 크론에 ISO week 체크 로직 추가
- 일요일에 답변 안 해도 월요일부터 자동 질문
- Week 기반 자동 판단으로 불필요한 반복 질문 제거

---

## Important Decisions

### 2026-02-05: Self-Healing System 구현 완료
- **목표:** Gateway 장애 시 4단계 자동 복구 시스템 구축
- **구조:**
  - **Level 1 (Watchdog):** 180초 간격 프로세스 감시 (기존)
  - **Level 2 (Health Check):** 5분 간격 HTTP 200 체크 + 3회 재시도 (신규)
  - **Level 3 (Claude Recovery):** tmux + Claude Code로 30분간 자동 진단 및 복구 (신규)
  - **Level 4 (Discord Notification):** 5분 간격 로그 모니터링 + #jarvis-health 알림 (신규)
- **스크립트:**
  - `~/openclaw/scripts/gateway-healthcheck.sh` (Level 2)
  - `~/openclaw/scripts/emergency-recovery.sh` (Level 3)
  - `~/openclaw/scripts/emergency-recovery-monitor.sh` (Level 4)
- **LaunchAgent:**
  - `~/Library/LaunchAgents/com.openclaw.healthcheck.plist` (Level 2)
- **Cron:**
  - ID: `eddd4e18-b995-4420-8465-7c6927280228` (Level 4 모니터링)
- **문서:** `~/openclaw/docs/self-healing-system.md`
- **검증:**
  - Level 1: ✅ 19:37 자동 재시작 확인 (프로세스 강제 종료)
  - Level 2: ✅ LaunchAgent 로드 및 5분 간격 실행 확인
  - Level 3: ⏳ 실제 장애 발생 시 테스트 예정
  - Level 4: ⏳ Emergency recovery 실패 시 테스트 예정
- **교훈:**
  - macOS pgrep 신뢰성 이슈 → HTTP 체크만 사용
  - Gateway cron API timeout 반복 → Gateway restart 필요
  - 메타 레벨 자가복구: "시스템이 스스로를 치료하지 못하면 외부 의사를 부른다"

### 2026-02-05: Kakao Calendar API 제한사항 확인
- **문제:** 휴대폰 카카오 앱에서 만든 일정 → API 조회 시 제목 없음
- **원인:** 테스트 앱 + "이용 중 동의" 권한 제약
- **해결:**
  - API로 새로 생성한 일정 → 조회/수정/삭제 가능 ✅
  - 휴대폰에서 만든 일정 → 수동 처리 필요
- **교훈:** 중요 일정은 처음부터 OpenClaw API로 등록
- **AWS SAA 시험:** 3월 7일(토) 하루종일로 API 생성 완료 (ID: 69841f38b6a6e101a943f755)

### 2026-02-05: Kakao OAuth Refresh Token 구현
- **Refresh Token 발급**: 60일 유효 (2026-04-06 만료)
- **자동 갱신 크론**: 5시간마다 access token 갱신 (`kakao-token-refresh.sh`)
- **만료 알림 크론**: 매일 09:00, 7일 이하 남았을 때 <#1468751194284621967> 알림
- **보안 개선**: Client Secret을 환경변수로 이동 (`KAKAO_CLIENT_SECRET`)
- **에러 핸들링**: 실패 시 `~/openclaw/memory/kakao-token-errors-YYYY-MM-DD.log` 기록 + Discord 알림
- **로그 rotation**: 7일 이상 된 에러 로그 자동 삭제 (매일 03:00)
- **Linux 호환성**: date 명령어 → Node.js로 변경 (portable)
- **Gateway restart 제거**: Runtime config reload (불필요한 재시작 제거)

### 2026-02-05: Odsay API 토큰 재발급 및 Referer 헤더 해결
- **문제:** 기존 API Key 인증 실패 (ApiKeyAuthFailed)
- **원인:** 
  1. 토큰 만료 (짧은 유효기간)
  2. URI 플랫폼 사용 시 Referer 헤더 필수
- **해결:**
  - 새 API Key 발급: `4/oBienvoQ+ufPGJf9lqlg`
  - 유효기간: **2026년 8월 5일까지 (6개월)**
  - Service URI: `macmini.tail75f63b.ts.net`, `localhost` 추가
  - **curl 사용 시 필수:** `-H "Referer: http://localhost/"`
- **설정:** `~/.openclaw/openclaw.json` → `ODSAY_API_KEY`
- **테스트 성공:** 경로 검색 API (52분/1,500원/15km)
- **크론 ID**: 
  - 자동 갱신: `a7cd38ad-8f72-4e93-af5e-a2aff72b186d`
  - 만료 알림: `cc5333f3-ddaa-4054-b4ce-c5153de3d5b9`
  - 로그 정리: `6bcf25e1-6588-46f7-8a32-4a5557a4f055`
- **비판적 평가 결과**: 6.8/10 → 8.6/10 → **9.2/10** (production-ready)

### 2026-02-05: 품질 체크 V4.0 전환 완료
- **V3.3 → V4.0 업그레이드** (정우님 지적: "V3.3은 옛날버전 왜존재?")
- **V4.0 주요 개선**:
  - **목표 대비 측정** — <15초, 0회 재시도, >95% 정확도
  - **의사결정 추론 (CoT)** — 도구 선택/접근 방법/트레이드오프 명시
  - **실패율 계산** — X회 호출 / Y회 실패 (Z%)
  - **토큰 예산 관리** — 예산 대비 사용률
- **정리 완료**:
  - V3.2, V3.3 파일 삭제 ✅
  - symlink → V4.0으로 변경 ✅
  - AGENTS.md 업데이트 ✅
- **틀 있는 곳**: `~/openclaw/templates/self-review-v4.0.md`
- **매주 살펴보기 크론**: 매주 일요일 23:30, Opus + Thinking High
- **크론 ID**: `6b9054f4-8afb-4c56-a875-8648a661653a`
- **가르침 있는 곳**: AGENTS.md "🔍 품질 체크 V4.0" 부분

### 2026-02-04: 품질 체크 V3.3 만들기 (deprecated)
- **V3.2 → V3.3 고침** (정우님 말씀: "자기만족이지 자기개선이 아니다")
- ⚠️ **2026-02-05에 V4.0으로 대체됨**

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

## Notes

- Memory files: `memory/YYYY-MM-DD.md` (daily logs)
- This file: Long-term curated facts
- "If you say 'remember this', write it here"
