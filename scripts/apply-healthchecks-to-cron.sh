#!/bin/bash
# 기존 크론탭에 healthcheck-ping 호출을 자동 추가
# 각 크론잡 끝에 && healthcheck-ping.sh <slug> 추가
#
# 안전: 이미 추가된 경우 스킵, 원본 백업

set -euo pipefail

HC_PING="$HOME/openclaw/scripts/healthcheck-ping.sh"
HC_CONFIG="$HOME/.openclaw/healthchecks.json"

if [[ ! -f "$HC_CONFIG" ]]; then
    echo "ERROR: healthchecks.json 없음. 먼저 setup-healthchecks.sh 실행" >&2
    exit 1
fi

# UUID가 설정되었는지 확인
first_uuid=$(jq -r '.checks | to_entries[0].value' "$HC_CONFIG" 2>/dev/null)
if [[ "$first_uuid" == "REPLACE_WITH_UUID" ]]; then
    echo "ERROR: healthchecks.json에 UUID가 아직 설정되지 않음" >&2
    echo "먼저 setup-healthchecks.sh <API_KEY> 실행" >&2
    exit 1
fi

# 크론탭 백업
BACKUP="/tmp/crontab-backup-$(date +%Y%m%d-%H%M%S)"
crontab -l > "$BACKUP" 2>/dev/null
echo "크론탭 백업: $BACKUP"

# 매핑 (크론 스크립트 → healthchecks slug)
declare -A CRON_MAP=(
    ["launchd-guardian.sh"]="guardian"
    ["discord-rate-monitor.sh"]="rate-monitor"
    ["latency-tracker.sh"]="latency-tracker"
    ["security-audit.sh"]="security-audit"
    ["level2-auto-tune.js"]="level2-tune"
    ["morning-standup.sh"]="morning-standup"
    ["server_maintenance.sh"]="maintenance"
)

CURRENT=$(crontab -l 2>/dev/null)
UPDATED="$CURRENT"

for script in "${!CRON_MAP[@]}"; do
    slug="${CRON_MAP[$script]}"

    # 이미 healthcheck-ping이 있으면 스킵
    if echo "$UPDATED" | grep "$script" | grep -q "healthcheck-ping"; then
        echo "  스킵: $script (이미 적용됨)"
        continue
    fi

    # 해당 크론 라인 찾아서 끝에 ping 추가
    if echo "$UPDATED" | grep -q "$script"; then
        UPDATED=$(echo "$UPDATED" | sed "/$script/s|$| \&\& $HC_PING $slug 2>/dev/null|")
        echo "  ✓ 적용: $script → $slug"
    else
        echo "  스킵: $script (크론에 없음)"
    fi
done

# 적용
echo "$UPDATED" | crontab -
echo ""
echo "✓ 크론탭 업데이트 완료"
echo "  확인: crontab -l"
