# 외부 모니터링 설정 가이드 (UptimeRobot)

## 왜 필요한가?

로컬 Watchdog만으로는 100% 신뢰할 수 없습니다:
- macOS 유휴 상태 시 LaunchAgent 스케줄링 지연
- Watchdog 자체가 죽으면 감지 불가
- 네트워크 레벨 장애 미감지

**외부에서 `/health` 엔드포인트를 체크**하면 이 문제들을 해결할 수 있습니다.

---

## UptimeRobot 설정 (무료)

### 1단계: 계정 생성

1. https://uptimerobot.com/ 접속
2. **Sign Up Free** 클릭
3. 이메일로 가입 (Google OAuth 가능)

### 2단계: 모니터 추가

1. **+ Add New Monitor** 클릭
2. 설정:
   - **Monitor Type:** HTTP(s)
   - **Friendly Name:** OpenClaw Gateway
   - **URL:** `https://macmini.tail75f63b.ts.net/health`
   - **Monitoring Interval:** 5 minutes (무료 최소)

### 3단계: 알림 설정

1. **Alert Contacts** 섹션
2. **Add Alert Contact** → Email 추가
3. (선택) Discord Webhook:
   - Type: Webhook
   - URL: Discord 채널의 Webhook URL
   - POST 데이터: `{"content": "*monitorFriendlyName* is *alertTypeFriendlyName*"}`

---

## Tailscale Funnel 설정 (이미 완료)

OpenClaw는 이미 Tailscale Funnel로 외부 접근 가능:
```
https://macmini.tail75f63b.ts.net/
```

Health 엔드포인트:
```
https://macmini.tail75f63b.ts.net/health
```

---

## 무료 플랜 제한

| 항목 | 무료 플랜 |
|------|----------|
| 모니터 수 | 50개 |
| 체크 간격 | 5분 |
| 알림 연락처 | 무제한 |
| 로그 보관 | 2개월 |

충분합니다.

---

## 테스트

```bash
# 외부에서 접근 테스트
curl -s https://macmini.tail75f63b.ts.net/health
```

응답: `{"status":"ok"}` 또는 HTTP 200

---

## Discord Webhook 설정 (선택)

1. Discord 서버 설정 → 연동 → 웹훅
2. #jarvis-system 채널에 웹훅 생성
3. URL 복사
4. UptimeRobot에 Webhook Alert Contact로 추가

---

## 예상 효과

- 장애 발생 시 **5분 내 외부 알림**
- 로컬 Watchdog과 **이중 감시**
- 네트워크/DNS 레벨 장애도 감지
