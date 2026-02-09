# n8n 샘플 워크플로우

## 1. 이메일 → Discord 알림 (추천 ⭐)

**용도:** 중요 이메일 수신 시 Discord #jarvis 채널로 알림

### 설정 방법

1. n8n 웹 UI 접속 (http://localhost:5678)
2. **New Workflow** 클릭
3. 다음 노드 추가:

```
[Gmail Trigger] → [IF 조건] → [Discord Webhook]
```

### 노드 설정

**Gmail Trigger:**
- Credential: Google OAuth2 (새로 생성)
- Poll Time: 5분
- Labels: INBOX

**IF 조건:**
- 조건: `{{$json.from.includes("important")}}` 또는 특정 발신자

**Discord Webhook:**
- Webhook URL: Discord 채널 설정에서 생성
- Message: `📧 새 이메일\n발신: {{$json.from}}\n제목: {{$json.subject}}`

---

## 2. RSS → 뉴스레터 오디오 변환

**용도:** 블로그 RSS 새 글 → TTS 오디오 생성 → Discord 전송

### 노드 구성

```
[RSS Trigger] → [OpenAI TTS] → [Discord File Upload]
```

### 설정

**RSS Trigger:**
- Feed URL: 관심 블로그 RSS
- Poll Time: 1시간

**OpenAI TTS (HTTP Request):**
- URL: `https://api.openai.com/v1/audio/speech`
- Method: POST
- Body:
```json
{
  "model": "tts-1",
  "input": "{{$json.contentSnippet}}",
  "voice": "nova",
  "speed": 1.1
}
```

---

## 3. 스케줄 기반 시스템 상태 리포트

**용도:** 매일 아침 맥미니 상태를 Discord로 전송

### 노드 구성

```
[Schedule Trigger] → [Execute Command] → [Discord Webhook]
```

### 설정

**Schedule Trigger:**
- Cron: `0 7 * * *` (매일 07:00)

**Execute Command:**
```bash
echo "=== CPU ===" && top -l 1 | head -5
echo "=== Memory ===" && memory_pressure | head -3
echo "=== Disk ===" && df -h / | tail -1
```

---

## 4. GitHub Issue → Slack/Discord 알림

**용도:** GitHub repo에 새 이슈 생성 시 알림

### 노드 구성

```
[GitHub Trigger] → [Discord Webhook]
```

### 설정

**GitHub Trigger:**
- Events: Issues (opened)
- Repository: Ramsbaby/openclaw-self-healing

---

## 자비스 권장 순위

| 순위 | 워크플로우 | 난이도 | 가치 |
|------|-----------|--------|------|
| 1 | 이메일 → Discord | 쉬움 | 높음 |
| 2 | 시스템 상태 리포트 | 중간 | 높음 |
| 3 | RSS → 오디오 | 어려움 | 중간 |
| 4 | GitHub → 알림 | 쉬움 | 낮음 |

## 다음 단계

1. n8n 웹 UI에서 Gmail OAuth 연동
2. Discord Webhook URL 생성
3. 워크플로우 1번부터 구축
