# API OAuth 자동화 설정 가이드

## 1. OpenAI API 사용량 자동 조회

### 옵션 A: Organization API (권장)
정우님이 OpenAI Organization 계정을 가지고 있다면:

1. Organization ID 확인
   ```
   https://platform.openai.com/account/org-settings/general
   → "Organization ID: org-xxxxx"
   ```

2. Organization API Key 생성
   ```
   https://platform.openai.com/account/org-settings/api-keys
   → "Create new secret key" (Organization scope)
   ```

3. 환경변수 설정
   ```bash
   export OPENAI_ORG_ID="org-xxxxx"
   export OPENAI_API_KEY_ORG="sk-org-xxxxx"  # Organization key (별도)
   ```

4. 스크립트로 자동 조회
   ```bash
   curl https://api.openai.com/v1/organization/usage \
     -H "Authorization: Bearer $OPENAI_API_KEY_ORG" \
     -H "OpenAI-Organization: $OPENAI_ORG_ID"
   ```

### 옵션 B: Personal 계정 + 웹 스크래핑
Personal 계정만 있다면:

1. Platform 토큰 확인
   ```
   DevTools → Application → Cookies → "platform.openai.com"
   → "session" 또는 "__Secure-next-auth.session-token"
   ```

2. Playwright로 대시보드 스크래핑
   ```bash
   npx playwright codegen https://platform.openai.com/account/billing/overview
   ```

---

## 2. Brave Search API 사용량 자동 조회

### API 엔드포인트
```
GET https://api.search.brave.com/res/v1/billing/subscription/state
Authorization: Bearer <API_KEY>
```

환경변수:
```bash
export BRAVE_API_KEY="<your_brave_api_key>"
```

테스트:
```bash
curl -s https://api.search.brave.com/res/v1/billing/subscription/state \
  -H "Accept: application/json" \
  -H "X-Subscription-Token: $BRAVE_API_KEY"
```

---

## 3. 자동 갱신 크론 설정

Once 토큰 설정되면:

```bash
# 크론 생성: 매일 06:00 + 18:00
openclaw cron add \
  --name "API 사용량 자동 갱신" \
  --schedule "0 6,18 * * *" \
  --task "~/openclaw/scripts/fetch-api-usage.sh"
```

---

## 필요한 정보

정우님께 확인 필요:

1. **OpenAI**
   - Organization ID 있는가? (있으면 org-xxxxx)
   - Personal 계정만 있는가?

2. **Brave Search**
   - 현재 API 키: $BRAVE_API_KEY (이미 환경변수 있음)

정우님 답변 받은 후, 스크립트 자동화 진행하겠습니다.
