#!/bin/bash
# Kakao OAuth 토큰 발급 및 갱신 스크립트

set -e

REST_API_KEY="${KAKAO_REST_API_KEY:-YOUR_KAKAO_API_KEY_HERE}"
REDIRECT_URI="http://localhost:8080/callback"
CONFIG_FILE="$HOME/.openclaw/openclaw.json"

echo "🔐 Kakao OAuth 토큰 발급"
echo ""
echo "1단계: 브라우저에서 아래 URL을 열어주세요"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "https://kauth.kakao.com/oauth/authorize?client_id=${REST_API_KEY}&redirect_uri=${REDIRECT_URI}&response_type=code&prompt=login"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "※ 로그인 후 'localhost에 연결할 수 없음' 에러가 나타나면 정상입니다."
echo "   주소창의 URL에서 code=XXX 부분을 복사하세요."
echo ""
echo "2단계: 로그인 후 리다이렉트된 URL에서 'code=' 뒤의 값을 복사하세요"
echo "예: http://localhost:8080/callback?code=XXXXX"
echo "    → XXXXX 부분을 복사"
echo ""
read -p "인가 코드를 입력하세요: " AUTH_CODE

if [ -z "$AUTH_CODE" ]; then
    echo "❌ 인가 코드가 비어있습니다."
    exit 1
fi

echo ""
echo "3단계: 토큰 발급 중..."

# 토큰 발급
RESPONSE=$(curl -s -X POST "https://kauth.kakao.com/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=${REST_API_KEY}" \
  -d "redirect_uri=${REDIRECT_URI}" \
  -d "code=${AUTH_CODE}")

# 결과 확인
if echo "$RESPONSE" | jq -e '.access_token' > /dev/null 2>&1; then
    ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
    REFRESH_TOKEN=$(echo "$RESPONSE" | jq -r '.refresh_token')
    EXPIRES_IN=$(echo "$RESPONSE" | jq -r '.expires_in')
    REFRESH_EXPIRES_IN=$(echo "$RESPONSE" | jq -r '.refresh_token_expires_in')
    
    echo "✅ 토큰 발급 성공!"
    echo ""
    echo "Access Token: ${ACCESS_TOKEN:0:20}..."
    echo "Refresh Token: ${REFRESH_TOKEN:0:20}..."
    echo "Access Token 만료: ${EXPIRES_IN}초 ($(($EXPIRES_IN / 3600))시간)"
    echo "Refresh Token 만료: ${REFRESH_EXPIRES_IN}초 ($(($REFRESH_EXPIRES_IN / 86400))일)"
    echo ""
    
    # OpenClaw config 업데이트
    echo "4단계: OpenClaw 설정 업데이트 중..."
    
    TMP_FILE=$(mktemp)
    jq --arg access "$ACCESS_TOKEN" \
       --arg refresh "$REFRESH_TOKEN" \
       '.env.vars.KAKAO_ACCESS_TOKEN = $access | 
        .env.vars.KAKAO_REFRESH_TOKEN = $refresh' \
       "$CONFIG_FILE" > "$TMP_FILE"
    
    mv "$TMP_FILE" "$CONFIG_FILE"
    
    echo "✅ 설정 저장 완료: $CONFIG_FILE"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Gateway 재시작이 필요합니다:"
    echo "  openclaw gateway restart"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "❌ 토큰 발급 실패"
    echo "$RESPONSE" | jq '.'
    exit 1
fi
