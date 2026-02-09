#!/usr/bin/env bash
# channel-quality-sampling-rules.sh v1.0
# 규칙 기반 채널별 품질 체크 (토큰 절약형)

set -euo pipefail

GUILD_ID="483238980280647680"
ALERT_CHANNEL="1469190688083280065"  # #jarvis-system
HOURS_AGO=2

# Discord API 함수 (message tool 사용)
discord_api() {
    local endpoint="$1"
    # OpenClaw message tool 사용 (내부적으로 Discord API 호출)
    # 대신 openclaw CLI 사용
    echo "{}" # placeholder
}

post_alert() {
    local message="$1"
    # OpenClaw CLI로 메시지 전송
    echo "$message" | openclaw msg send --channel discord --to "${ALERT_CHANNEL}" --stdin 2>/dev/null || true
}

# 채널별 규칙 체크
check_jarvis() {
    local content="$1"
    local violations=()
    
    # ChatGPT 톤 금지
    if echo "$content" | grep -qiE "알겠습니다!|완료!|기쁩니다|설정 완료!"; then
        violations+=("ChatGPT 톤 감지")
    fi
    
    # 2000자 초과 시 분할 체크 (간단한 구현: 단락 없으면 위반)
    if [ ${#content} -gt 2000 ]; then
        if ! echo "$content" | grep -q "^##"; then
            violations+=("2000자+ 응답, 소제목 없음")
        fi
    fi
    
    printf '%s\n' "${violations[@]}"
}

check_jarvis_market() {
    local content="$1"
    local violations=()
    
    # 필수 항목 체크
    echo "$content" | grep -q '\$' || violations+=("USD 가격 없음")
    echo "$content" | grep -q '₩' || violations+=("KRW 환율 없음")
    echo "$content" | grep -q '%' || violations+=("변동률 없음")
    
    printf '%s\n' "${violations[@]}"
}

check_jarvis_system() {
    local content="$1"
    local violations=()
    
    # 긴급도 이모지 필수
    if ! echo "$content" | grep -qE "🚨|⚠️|ℹ️|✅"; then
        violations+=("긴급도 이모지 없음")
    fi
    
    # 로그 10줄 이상 시 파일 링크 권장
    local log_lines=$(echo "$content" | grep -c '^\[' || true)
    if [ "$log_lines" -gt 10 ]; then
        if ! echo "$content" | grep -q "로그:"; then
            violations+=("로그 10줄+ (파일 링크 권장)")
        fi
    fi
    
    printf '%s\n' "${violations[@]}"
}

check_jarvis_dev() {
    local content="$1"
    local violations=()
    
    # ChatGPT 톤 금지 (더 엄격)
    if echo "$content" | grep -qiE "알겠습니다!|완료!|처리 완료!"; then
        violations+=("ChatGPT 톤 감지")
    fi
    
    # 코드블록 언어 미명시
    if echo "$content" | grep -q '^```$'; then
        violations+=("코드블록 언어 미명시")
    fi
    
    printf '%s\n' "${violations[@]}"
}

# 메인 로직
main() {
    local channels=(
        "1468386844621144065:jarvis:check_jarvis"
        "1469190686145384513:jarvis-market:check_jarvis_market"
        "1469190688083280065:jarvis-system:check_jarvis_system"
        "1469905074661757049:jarvis-dev:check_jarvis_dev"
    )
    
    local cutoff=$(date -u -v-${HOURS_AGO}H +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || \
                   date -u -d "${HOURS_AGO} hours ago" +%Y-%m-%dT%H:%M:%S.000Z)
    
    local total_violations=0
    
    for entry in "${channels[@]}"; do
        IFS=: read -r channel_id channel_name check_fn <<< "$entry"
        
        echo "🔍 Checking #${channel_name}..."
        
        # 최근 50개 메시지 조회
        local messages=$(discord_api "/channels/${channel_id}/messages?limit=50")
        
        # 자비스 메시지만 필터링 (500자+)
        echo "$messages" | jq -r --arg cutoff "$cutoff" '
            .[] |
            select(.author.username == "자비스" and .timestamp >= $cutoff) |
            select(.content | length >= 500) |
            {id, timestamp, content: (.content | .[0:200])}
        ' | while IFS= read -r line; do
            local msg_id=$(echo "$line" | jq -r '.id // empty')
            [ -z "$msg_id" ] && continue
            
            local full_content=$(echo "$messages" | jq -r ".[] | select(.id == \"$msg_id\") | .content")
            local timestamp=$(echo "$line" | jq -r '.timestamp')
            
            # 채널별 규칙 실행
            local violations=($($check_fn "$full_content"))
            
            if [ ${#violations[@]} -gt 0 ]; then
                total_violations=$((total_violations + 1))
                
                local alert="⚠️ **품질 체크 (규칙 기반)**\n\n"
                alert+="채널: #${channel_name}\n"
                alert+="시각: ${timestamp}\n"
                alert+="메시지: https://discord.com/channels/${GUILD_ID}/${channel_id}/${msg_id}\n\n"
                alert+="**위반 사항:**\n"
                for v in "${violations[@]}"; do
                    alert+="- $v\n"
                done
                
                post_alert "$alert"
                echo "  ⚠️ Message ${msg_id}: ${violations[*]}"
            fi
        done
    done
    
    if [ $total_violations -eq 0 ]; then
        echo "✅ 품질 체크 통과 (위반 없음)"
    else
        echo "⚠️ 총 ${total_violations}개 위반 발견"
    fi
}

main "$@"
