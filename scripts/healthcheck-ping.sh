#!/bin/bash
# Healthchecks.io Dead Man's Switch Ping
# 크론잡 성공 시 호출 → 예상 시간에 ping 안 오면 알림
#
# 사용법:
#   성공: healthcheck-ping.sh <slug>
#   시작: healthcheck-ping.sh <slug> /start
#   실패: healthcheck-ping.sh <slug> /fail
#
# 크론에서:
#   healthcheck-ping.sh guardian/start && guardian.sh && healthcheck-ping.sh guardian
#
# 설정: ~/.openclaw/healthchecks.json 에 ping URL 저장

HC_CONFIG="$HOME/.openclaw/healthchecks.json"

if [[ ! -f "$HC_CONFIG" ]]; then
    # 설정 없으면 무시 (graceful skip)
    exit 0
fi

PING_BASE=$(jq -r '.ping_url' "$HC_CONFIG" 2>/dev/null)
if [[ -z "$PING_BASE" ]] || [[ "$PING_BASE" == "null" ]]; then
    exit 0
fi

SLUG="${1:-}"
ACTION="${2:-}"

if [[ -z "$SLUG" ]]; then
    echo "Usage: healthcheck-ping.sh <slug> [/start|/fail]" >&2
    exit 1
fi

# UUID 매핑 (slug → uuid)
UUID=$(jq -r ".checks[\"$SLUG\"] // empty" "$HC_CONFIG" 2>/dev/null)

if [[ -z "$UUID" ]]; then
    # slug 자체가 UUID일 수 있음
    UUID="$SLUG"
fi

# Ping 전송 (5초 타임아웃, 최대 3회 재시도)
curl -fsS -m 5 --retry 3 "${PING_BASE}/${UUID}${ACTION}" > /dev/null 2>&1 || true
