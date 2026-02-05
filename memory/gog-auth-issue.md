# GOG Auth Issue

> 2026-02-05: gog auth login 반복 필요 문제

## 증상
- 어제(2026-02-04) `gog auth login` 실행
- 오늘(2026-02-05) 또 `gog auth login` 필요
- 토큰이 하루도 안 돼서 만료되는 것으로 추정

## 테스트 결과

### gog auth status
```
✅ config_exists: true
✅ credentials_exists: true
✅ account: your-email@example.com
✅ auth_preferred: oauth
```

### gog calendar events list --today
```
❌ Google API error (404 notFound): Not Found
```

## 가능한 원인

### 1. Token Refresh 실패
- gog CLI가 OAuth refresh token을 자동 갱신하지 못함
- Access token 만료 (1시간) 후 refresh 안 됨

### 2. Keychain 문제
- macOS Keychain에서 토큰 검색 실패
- 권한 문제로 토큰 읽기 불가

### 3. Google Calendar API 미활성화
- OAuth consent screen 설정 문제
- API scope 누락
- Calendar API 활성화 안 됨

### 4. 404 Not Found 원인
- Calendar ID 잘못됨 (primary 사용했는데 없음)
- API 자체가 비활성화
- 권한 없는 리소스 접근

## 디버깅 계획

### 단계 1: Verbose 로그 확인
```bash
gog calendar events list --today --verbose 2>&1
```

### 단계 2: Token 상태 확인
```bash
# Keychain에 저장된 토큰 확인
security find-generic-password -s "gogcli-your-email@example.com" 2>&1
```

### 단계 3: OAuth Scope 확인
```bash
# gog auth status에서 scope 확인
gog auth status --verbose 2>&1
```

### 단계 4: Google Cloud Console 확인
1. https://console.cloud.google.com
2. APIs & Services → Enabled APIs → Calendar API 활성화 확인
3. OAuth 2.0 Client IDs → Redirect URI 확인
4. OAuth consent screen → Scopes 확인

## 해결 방안

### 임시: Kakao Calendar 사용
- ✅ 이미 구현됨
- ✅ Refresh token 자동 갱신 크론 있음
- ✅ 안정적으로 작동 중

### 장기: GOG 토큰 자동 갱신 크론
```bash
# 매 30분마다 gog 명령어 실행 → 자동 refresh 트리거
*/30 * * * * gog calendar calendars --no-input 2>&1 | logger -t gog-keepalive
```

**문제점:** gog가 자동 refresh를 지원하지 않으면 무용지물

### 최종: gog 대신 다른 CLI
- `gcalcli` - Python 기반, refresh token 자동 갱신
- Google Calendar API 직접 호출 (Node.js/curl)

## 현재 상태
- ⏸️ 정우님 요청으로 나중으로 미룸
- ✅ Kakao Calendar로 대체 가능
- 🔍 필요 시 재조사

## Next Steps (보류)
1. `gog calendar events --verbose` 실행
2. 404 에러 원인 파악
3. Token refresh 메커니즘 확인
4. 필요시 gcalcli 전환 검토
