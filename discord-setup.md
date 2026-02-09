# Discord 확장형 설정 가이드

## 🚨 보안: 토큰 재발급 필수

토큰이 노출되었으므로 즉시 재발급하세요.

1. Discord Developer Portal → Your App → Bot
2. "Reset Token" 클릭
3. 새 토큰 복사 (한 번만 보여줌)

## 🎯 확장형 권한 설정

### 1단계: Bot Permissions (OAuth2 → URL Generator)

**Scopes:**
- ✅ bot
- ✅ applications.commands

**Bot Permissions (확장형):**

**Text Permissions:**
- ✅ View Channels
- ✅ Send Messages
- ✅ Send Messages in Threads
- ✅ Create Public Threads
- ✅ Create Private Threads
- ✅ Embed Links
- ✅ Attach Files
- ✅ Add Reactions
- ✅ Use External Emojis
- ✅ Use External Stickers
- ✅ Mention @everyone, @here, and All Roles
- ✅ Manage Messages (메시지 편집/삭제)
- ✅ Manage Threads (스레드 관리)
- ✅ Read Message History
- ✅ Use Slash Commands

**Voice Permissions (선택):**
- ✅ Connect (음성 채널 접속)
- ✅ Speak (음성 전송)

**Advanced Permissions (선택적 - 주의):**
- ⚠️ Manage Channels (채널 생성/수정 - 필요 시만)
- ⚠️ Manage Roles (역할 관리 - 필요 시만)
- ❌ Administrator (절대 주지 마세요 - 보안 위험)

### 2단계: Intents 활성화

Bot → Privileged Gateway Intents:

- ✅ Presence Intent (온라인/오프라인 상태)
- ✅ Server Members Intent (멤버 목록 조회)
- ✅ Message Content Intent (필수 - 메시지 읽기)

### 3단계: OpenClaw 확장 설정

`~/.openclaw/config.yml` 파일:

```yaml
channels:
  discord:
    enabled: true
    token: "YOUR_NEW_BOT_TOKEN"  # 재발급한 토큰
    
    # DM 설정
    dm:
      enabled: true
      policy: "pairing"  # 첫 접촉 시 승인 필요
      allowFrom: ["YOUR_DISCORD_USER_ID"]
    
    # 파일 업로드 제한
    mediaMaxMb: 25  # Discord 기본 25MB (Nitro는 500MB)
    
    # 메시지 청킹
    textChunkLimit: 2000
    maxLinesPerMessage: 30
    chunkMode: "newline"  # 문단 단위로 나누기
    
    # 확장 기능 활성화
    actions:
      reactions: true        # 반응 추가
      stickers: true         # 스티커 전송
      emojiUploads: true     # 이모지 업로드
      polls: true            # 투표 생성
      messages: true         # 메시지 편집/삭제
      threads: true          # 스레드 생성/관리
      pins: true             # 메시지 고정
      search: true           # 메시지 검색
      memberInfo: true       # 멤버 정보 조회
      roleInfo: true         # 역할 정보 조회
      channelInfo: true      # 채널 정보 조회
      channels: true         # 채널 생성/관리
      voiceStatus: true      # 음성 상태 조회
      events: true           # 이벤트 생성
      roles: false           # 역할 부여 (위험 - 필요 시만)
      moderation: false      # 타임아웃/킥/밴 (위험)
    
    # 서버(길드) 설정 (선택)
    guilds:
      "YOUR_GUILD_ID":  # 서버 ID (우클릭 → Copy Server ID)
        requireMention: false  # 멘션 없이도 응답
        users: ["YOUR_DISCORD_USER_ID"]  # 허용된 사용자
        channels:
          general:  # 채널 이름
            allow: true
            requireMention: false
    
    # 리플라이 모드
    replyToMode: "first"  # off | first | all
    
    # 재시도 정책
    retry:
      attempts: 3
      minDelayMs: 500
      maxDelayMs: 30000
      jitter: 0.1
```

### 4단계: Discord ID 확인

Discord에서 Developer Mode 켜기:

1. 설정(톱니바퀴) → 고급 → Developer Mode ON
2. 우클릭으로 ID 복사:
   - 프로필 우클릭 → "Copy User ID"
   - 서버 이름 우클릭 → "Copy Server ID"
   - 채널 우클릭 → "Copy Channel ID"

### 5단계: 환경변수 방식 (대안)

config.yml 대신 환경변수로도 가능:

```bash
export DISCORD_BOT_TOKEN="YOUR_NEW_TOKEN"
```

그 후 Gateway 재시작:

```bash
openclaw gateway restart
```

### 6단계: Pairing 승인

DM으로 봇에게 메시지 보내면 pairing code가 나옵니다:

```bash
openclaw pairing list
openclaw pairing approve discord <CODE>
```

## 🎮 확장 기능 사용법

### 반응(Reaction) 추가
Discord에서 메시지에 이모지 반응을 달 수 있습니다.

### 스레드 생성
긴 대화를 스레드로 정리할 수 있습니다.

### 메시지 편집/삭제
봇이 보낸 메시지를 수정하거나 삭제할 수 있습니다.

### 파일 업로드
25MB까지 파일을 첨부할 수 있습니다.

### 투표(Poll) 생성
Discord 네이티브 투표 기능을 사용할 수 있습니다.

## 🔍 트러블슈팅

### 봇이 응답 안 함
1. Intents가 모두 켜져 있는지 확인
2. 초대 URL이 올바른 권한으로 생성됐는지 확인
3. `openclaw doctor` 실행
4. `openclaw channels status --probe` 실행

### Permission 에러
봇에게 채널 접근 권한이 있는지 확인하세요.

### Rate Limit
Discord API는 rate limit이 있습니다. 너무 많은 메시지를 빠르게 보내면 제한됩니다.

## ⚡ 빠른 시작 요약

1. 토큰 재발급 (Reset Token)
2. Intents 3개 모두 켜기
3. 초대 URL 재생성 (확장 권한 포함)
4. 서버에 재초대
5. config.yml 업데이트
6. `openclaw gateway restart`
7. DM 테스트 → pairing 승인

## 📋 체크리스트

- [ ] 토큰 재발급 완료
- [ ] Intents 3개 활성화
- [ ] 확장 권한으로 초대 URL 생성
- [ ] 서버에 봇 재초대
- [ ] config.yml 작성
- [ ] Gateway 재시작
- [ ] DM 테스트
- [ ] Pairing 승인
- [ ] 첫 대화 성공

---

작성일: 2026-02-04
