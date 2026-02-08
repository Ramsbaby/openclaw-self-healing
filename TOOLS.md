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
echo "=== Memory ===" && top -l 1 | grep PhysMem
echo "=== Disk ===" && df -h / | tail -1
```

**메모리 정보 상세:**
- `top -l 1 | grep PhysMem` → 실제 사용량 표시
- 출력 예시: `PhysMem: 14G used (2180M wired, 2984M compressor), 1335M unused.`
- ~~`memory_pressure | head -3`~~ (압력 상태만 표시, 사용량 누락)

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

**계정:** `yuiopnm1931@gmail.com`
**Keyring:** `keychain` (macOS Keychain 사용)

**사용법:**
```bash
gog tasks lists --account yuiopnm1931@gmail.com                           # 목록 보기
gog tasks list "목록ID" --account yuiopnm1931@gmail.com                   # 할 일 보기
gog tasks add "목록ID" --title "제목" --due "YYYY-MM-DD" --account yuiopnm1931@gmail.com  # 추가
gog tasks done "목록ID" "할일ID" --account yuiopnm1931@gmail.com          # 완료
```

**정우님 설정:**
- 기본 목록 ID: `MDE3MjE5NzU0MjA3NTAxOTg4ODc6MDow`
- 목록 이름: "내 할 일 목록"
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

**스킬 위치:** `gog calendar` (gog CLI)

**계정:** `yuiopnm1931@gmail.com`
**Keyring:** `keychain` (macOS Keychain 사용)

**사용법:**
```bash
gog calendar calendars --account yuiopnm1931@gmail.com         # 캘린더 목록
gog calendar events --account yuiopnm1931@gmail.com --today    # 오늘 일정
gog calendar events --account yuiopnm1931@gmail.com --from today --to "YYYY-MM-DD"  # 기간 일정
```

**캘린더 목록:**
- `yuiopnm1931@gmail.com` — 기본 캘린더
- `family02071296738162305992@group.calendar.google.com` — 가족
- `ko.south_korea#holiday@group.v.calendar.google.com` — 대한민국 휴일

**특이사항:**
- Kakao Calendar API와 병행 사용
- Kakao Calendar: 생성/수정 (ACCESS_TOKEN 필요)
- Google Calendar: 조회용 (gog CLI)
- ⚠️ 명령어는 `gog cal` 아니라 `gog calendar`

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

## 🔍 웹검색 필수 소스 (정우님 지침)

**"웹검색해줘" 요청 시 반드시 아래 소스 모두 확인:**

1. **일반 검색** — Brave Search (web_search)
2. **ClawHub** — `clawhub search` 또는 clawhub.com
3. **Moltbook** — moltbook.com (AI 에이전트 커뮤니티)
4. **OpenClaw GitHub Issues** — github.com/nicepkg/openclaw/issues
5. **Reddit** — r/LocalLLaMA, r/MachineLearning, r/programming 등
6. **GeekNews** — news.hada.io (한국 IT 뉴스)

**검색 순서:**
1. Brave Search로 일반 검색
2. 주제에 따라 관련 소스 추가 확인
3. AI/에이전트 관련 → ClawHub, Moltbook 필수
4. OpenClaw 관련 → GitHub Issues 필수

---

## 🛡️ ClawHub 스킬 설치 규칙 (필수!)

**ClawHub에서 스킬 설치 전 반드시 Clawdex 안전검사:**

```bash
curl -s "https://clawdex.koi.security/api/skill/스킬명"
```

**결과 해석:**
- `"verdict": "benign"` → ✅ 설치 OK
- `"verdict": "malicious"` → 🚫 **절대 설치 금지**
- `"verdict": "unknown"` → ⚠️ 정우님 승인 필요

**배경:** ClawHub에 341개 악성 스킬 발견됨 (ClawHavoc 캠페인)

**이미 설치된 스킬 전체 검사:**
```bash
for skill in $(ls ~/openclaw/skills/); do
  echo -n "$skill: "
  curl -s "https://clawdex.koi.security/api/skill/$skill" | jq -r '.verdict'
done
```

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

---

## n8n 자동화 플랫폼 (2026-02-07 설치)

**접속 URL:**
- 로컬: http://localhost:5678
- 원격: http://macmini.tail75f63b.ts.net:5678

**Docker 명령어:**
- 시작: `docker start n8n`
- 중지: `docker stop n8n`
- 로그: `docker logs n8n --tail 50`

**데이터 위치:** `~/.n8n/`

**활용 예시:**
- 이메일 → AI 요약 → Discord 전송
- RSS 피드 → 오디오 브리핑 생성
- 정기 보고서 자동화

**가이드:** `~/openclaw/docs/n8n-integration.md`

---

## 뉴스레터 오디오 브리핑

**스크립트:** `~/openclaw/scripts/newsletter-to-audio.sh`

**사용법:**
```bash
~/openclaw/scripts/newsletter-to-audio.sh "텍스트 내용" [output.mp3]
```

**특징:**
- OpenAI TTS API (nova 음성, 1.1x 속도)
- 4000자 이상 시 자동 청킹 + ffmpeg 병합
- 출력: MP3 파일

**요구사항:** OPENAI_API_KEY 환경변수

---

## 한글 숙제 자동 교정 (Preply 튜터 지원)

**스킬 위치:** `~/openclaw/scripts/homework-checker-v5.0.py` ⭐⭐⭐
**문서:** `~/openclaw/docs/korean-homework-correction-v2.md`
**용도:** 보람님(와이프) Preply 한국어 수업 지원

**평가:** ✅ 10.0/10.0 (Production Ready)

**v5.0 핵심 (2026-02-08):**
- Character-level 영역 병합 방식
- "아ㅍ요" 같은 불완전한 글자도 정확한 위치에 마킹
- Google Vision text_detection + 개별 글자 좌표 병합

**사용법 (Discord):**
1. 학생 숙제 이미지 업로드 (#jarvis-preply-tutor)
2. "교정해줘"
3. 자비스가 마킹된 이미지 + 평가 점수 전송

**명령줄:**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.openclaw/google-vision-key.json"
python3 ~/openclaw/scripts/homework-checker-v5.0.py <이미지경로>
```

**출력:**
- `<원본>_v2_corrected.jpg` — 빨간 밑줄(오류) + 초록 박스(교정)
- JSON — 오류 상세 + 평가 점수 (10점 만점)

**v2.0 기능:**
- ✅ Google Vision API (손글씨 95%+ 정확도)
- ✅ Bounding box 기반 정확한 위치 마킹
- ✅ 7가지 오류 유형 감지 (철자, 동사, 띄어쓰기, 불완전, 중복)
- ✅ 자동 평가 시스템 (10점 척도)
- ✅ Discord 통합

**무료 쿼터:**
- Google Vision API: 월 1000건 무료
- 이후 $1.50/1000건

**향후 계획:**
- [ ] GPT-4 문맥 분석 (Phase 3)
- [ ] 자동 학습 (보람님 피드백 반영) (Phase 4)
- [ ] 웹 대시보드 (Phase 5)

**관련 채널:**
- `1470011814803935274` — #jarvis-preply-tutor (보람님 전용)
