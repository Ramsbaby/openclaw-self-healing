# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

---

## Discord 설정

**Guild ID:** `483238980280647680`

**채널 ID:**
- `1468386844621144065` — #jarvis (메인 채널)
- `1469190686145384513` — #jarvis-market (시장 모니터링)
- `1469190688083280065` — #jarvis-system (시스템 알림)

**검색 시 사용법:**
```
message action:search guildId:483238980280647680 channelId:1468386844621144065 query:"검색어" limit:10
```

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

## "사용량" 요청 시 방침

**"사용량"이라고 하면 아래 3가지 모두 보고:**

### 1. ⚠️ Claude CLI 남은 한도 (최우선, 필수!)
```bash
# PTY로 반드시 실행 - 이게 제일 중요한 정보!
exec pty:true background:true command:"claude"
# 잠시 대기 후
process action:send-keys sessionId:XXX literal:"/usage"
process action:send-keys sessionId:XXX keys:["Enter"]
# 결과 확인
process action:poll sessionId:XXX
# 종료
process action:kill sessionId:XXX
```
→ **주간 남은 한도 %** 반드시 표시 (이거 빼먹으면 안 됨!)
→ 리셋 시간도 함께 표시

### 2. OpenClaw 세션 사용량
```bash
# session_status 도구 사용
session_status
```
→ 컨텍스트 사용량, 압축 횟수 표시

### 3. 맥미니 시스템 상태
```bash
# CPU, 메모리, 디스크 한번에
echo "=== CPU ===" && top -l 1 | head -10 | grep -E "CPU|Load"
echo "=== Memory ===" && memory_pressure | head -3
echo "=== Disk ===" && df -h / | tail -1
```

**통합 보고 형식:**

## 📊 사용량 리포트

### OpenClaw 세션
| 항목 | 값 |
|-----|-----|
| 토큰 | X |
| 비용 | $X.XX |
| 모델 | claude-xxx |

### 맥미니 상태
| 항목 | 값 |
|-----|-----|
| CPU | X% |
| 메모리 | X GB / Y GB |
| 디스크 | X% 사용 |
| Uptime | X일 X시간 |

---

## Yahoo Finance (주식 시세)

**스킬 위치:** `~/openclaw/skills/yahoo-finance/yf`

**사용법:**
```bash
yf TQQQ              # 간단 시세 (USD + KRW)
yf quote TQQQ        # 상세 시세
yf compare TQQQ,QQQ  # 종목 비교
```

**특이사항:**
- 15분 지연 데이터 (무료 Yahoo Finance API)
- 토스증권 실시간 가격과 $0.5~1 차이 가능
- 환율 자동 적용 (USD/KRW 실시간 조회)
- ±4% 변동 감지 시 경고 표시

**정우님 관심 종목:**
- TQQQ (ProShares UltraPro QQQ) - 3배 레버리지 ETF

---

## Google Tasks (할 일 관리)

**스킬 위치:** `gog tasks` (gog CLI)

**사용법:**
```bash
gog tasks lists                           # 목록 보기
gog tasks list "목록ID"                   # 할 일 보기
gog tasks add "목록ID" --title "제목" --due "YYYY-MM-DD"  # 추가
gog tasks done "목록ID" "할일ID"          # 완료
```

**정우님 설정:**
- 기본 목록 ID: `MDE3MjE5NzU0MjA3NTAxOTg4ODc6MDow`
- Galaxy 폰과 동기화
- **중요:** 할일/미리알림은 Google Tasks 사용 (Apple Reminders 아님)

---

## Apple Reminders (사용 안 함)

**스킬 위치:** `remindctl` CLI

**사용법:**
```bash
remindctl lists                                      # 목록
remindctl add "목록명" "할 일" --due "날짜시간"      # 추가
```

**특이사항:**
- Apple 기기만 동기화 (iPhone, iPad, Mac)
- **정우님은 Galaxy 폰 사용 → Google Tasks로 대체**

---

## Google Calendar (일정 관리)

**스킬 위치:** `gog cal` (gog CLI)

**사용법:**
```bash
gog cal today     # 오늘 일정
gog cal week      # 이번주 일정
```

**특이사항:**
- Kakao Calendar API와 병행 사용
- Kakao Calendar: 생성/수정 (ACCESS_TOKEN 필요)
- Google Calendar: 조회 전용 (gog CLI)

---

## 크론 템플릿

**위치**: `~/openclaw/templates/`

### 페르소나 지침
```
~/openclaw/templates/cron-persona.txt
```

**크론 메시지 작성 시**:
```bash
"$(cat ~/openclaw/templates/cron-persona.txt)

---

[실제 태스크 내용]"
```

**예상 효과**: 300-400 tokens → 50-100 tokens

---

Add whatever helps you do your job. This is your cheat sheet.

---

## 자동 일정 등록 (Kakao Calendar)

**날짜 감지 시 자동 제안:**
정우님이 대화 중 다음 패턴을 언급하면 일정 등록 제안:
- "X월 Y일" + 이벤트명 (예: "3월 7일 AWS SAA 시험")
- "다음 주 화요일" + 이벤트명
- "2/11 NFP 발표"

**제안 형식:**
```
📅 일정 등록할까요?
- 제목: [이벤트명]
- 날짜: [YYYY-MM-DD]
- 시간: [종일 / HH:MM]

등록하시려면 "등록해줘"라고 해주세요.
```

**등록 명령어:**
```bash
bash ~/openclaw/scripts/kakao-calendar-add.sh "제목" "시작(UTC)" "종료(UTC)" true "설명"
```

**예시:**
```bash
bash ~/openclaw/scripts/kakao-calendar-add.sh "NFP 고용지표 발표" "2026-02-11T12:30:00Z" "2026-02-11T13:30:00Z" false "미국 1월 고용지표"
```

**주의:** UTC 시간으로 변환 필요 (KST -9시간)
