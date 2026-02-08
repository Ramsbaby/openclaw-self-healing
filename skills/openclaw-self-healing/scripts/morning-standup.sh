#!/bin/bash
# Morning Briefing (통합) - 매일 아침 08:00 자동 실행
# 스탠드업 + 시스템 상태를 하나로 합쳐 Discord 전송
#
# 데이터 소스:
#   1. 시장 현황 (TQQQ 시세 - auto-retry 로그에서 추출)
#   2. Git log (어제 커밋)
#   3. Auto-retry 로그 (어제 실행 요약)
#   4. 인프라 메트릭 (Gateway, 메모리, CPU, 지연, 업타임)
#   5. Google Tasks (미완료 할 일)
#   6. Google Calendar (오늘 일정)
#   7. 블로커 감지 (연속 실패 + 인프라 이상 + 시장 급변)

set -euo pipefail

# .env에서 웹훅 로드
if [ -f "$HOME/openclaw/.env" ]; then
  source "$HOME/openclaw/.env"
fi
WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
OPENCLAW_DIR="$HOME/openclaw"
LOG_FILE="$OPENCLAW_DIR/logs/auto-retry.jsonl"
METRICS_FILE="$HOME/.openclaw/metrics/current.prom"
HISTORY_LOG="$HOME/.openclaw/metrics/history.csv"
GOG="$(which gog 2>/dev/null || echo '/opt/homebrew/bin/gog')"
GOG_ACCOUNT="yuiopnm1931@gmail.com"
TASKS_LIST_ID="MDE3MjE5NzU0MjA3NTAxOTg4ODc6MDow"

TODAY=$(date '+%Y-%m-%d')
YESTERDAY=$(date -v-1d '+%Y-%m-%d')
DAY_KR=$(date '+%a')
case "$DAY_KR" in
  Mon) DAY_KR="월" ;; Tue) DAY_KR="화" ;; Wed) DAY_KR="수" ;;
  Thu) DAY_KR="목" ;; Fri) DAY_KR="금" ;; Sat) DAY_KR="토" ;; Sun) DAY_KR="일" ;;
esac

echo "📋 Morning Briefing 생성 중... ($TODAY)"

# ============================================================================
# 1. 시장 현황 - TQQQ / SOXL / NVDA (yf 직접 호출)
#    (stock-briefing-with-retry.js 통합)
# ============================================================================
YF_CMD="$HOME/openclaw/skills/yahoo-finance/yf"
SYMBOLS="TQQQ SOXL NVDA"
MARKET_SECTION=""

parse_yf_oneline() {
  # yf 테이블 출력에서 한줄 요약 추출
  python3 -c "
import sys, re
out = sys.stdin.read()
sym = '${1}'
price = re.search(r'현재가 \(USD\)\s*│\s*(\\\$[\d.]+)', out)
change = re.search(r'변동 \(전일比\)\s*│\s*([^│]+)', out)
p = price.group(1).strip() if price else '?'
c = change.group(1).strip() if change else '?'
pct = re.search(r'([-+]?[\d.]+)%', c)
pct_val = abs(float(pct.group(1))) if pct else 0
alert = ''
if pct_val >= 5:
    alert = ' 🚨'
elif pct_val >= 3:
    alert = ' ⚠️'
print(f'  {sym}: {p} {c}{alert}')
" 2>/dev/null
}

for SYM in $SYMBOLS; do
  YF_OUT=$("$YF_CMD" "$SYM" 2>/dev/null || echo "")
  if [ -n "$YF_OUT" ]; then
    LINE=$(echo "$YF_OUT" | parse_yf_oneline "$SYM")
    MARKET_SECTION="${MARKET_SECTION}${LINE}\n"
  else
    MARKET_SECTION="${MARKET_SECTION}  ${SYM}: 조회 실패\n"
  fi
done

# 환율 (마지막 yf 출력에서 추출)
if [ -n "$YF_OUT" ]; then
  FX=$(echo "$YF_OUT" | grep "환율" | sed 's/.*│[[:space:]]*//' | sed 's/[[:space:]]*│.*//' | tr -d ' ')
  [ -n "$FX" ] && MARKET_SECTION="${MARKET_SECTION}  💱 ${FX}\n"
fi

# ============================================================================
# 2. 어제 한 일 - Git Commits
# ============================================================================
GIT_COMMITS=""
if [ -d "$OPENCLAW_DIR/.git" ]; then
  GIT_COMMITS=$(cd "$OPENCLAW_DIR" && git log --since="yesterday 00:00" --until="today 00:00" --oneline --all 2>/dev/null || echo "")
fi

COMMITS_SECTION=""
if [ -n "$GIT_COMMITS" ]; then
  while IFS= read -r line; do
    MSG=$(echo "$line" | sed 's/^[a-f0-9]* //')
    COMMITS_SECTION="${COMMITS_SECTION}  • ${MSG}\n"
  done <<< "$GIT_COMMITS"
else
  COMMITS_SECTION="  • 커밋 없음\n"
fi

# ============================================================================
# 3. 어제 Auto-Retry 로그 요약
# ============================================================================
RETRY_SECTION=""
if [ -f "$LOG_FILE" ]; then
  TOTAL=$(grep "\"$YESTERDAY" "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
  SUCCESS=$(grep "\"$YESTERDAY" "$LOG_FILE" 2>/dev/null | grep '"type":"success"' | wc -l | tr -d ' ')
  FAIL=$(grep "\"$YESTERDAY" "$LOG_FILE" 2>/dev/null | grep '"type":"failure"' | wc -l | tr -d ' ')

  if [ "$TOTAL" -gt 0 ]; then
    RATE=$(echo "scale=0; $SUCCESS * 100 / $TOTAL" | bc)
    RETRY_SECTION="  • Auto-Retry: ${TOTAL}회 실행, 성공률 ${RATE}%"
    if [ "$FAIL" -gt 0 ]; then
      RETRY_SECTION="${RETRY_SECTION} (실패 ${FAIL}건)"
    fi
    RETRY_SECTION="${RETRY_SECTION}\n"
  else
    RETRY_SECTION="  • Auto-Retry: 어제 실행 없음\n"
  fi
else
  RETRY_SECTION="  • Auto-Retry: 로그 없음\n"
fi

# ============================================================================
# 4. 인프라 메트릭 (metrics-report.sh daily 통합)
# ============================================================================
INFRA_SECTION=""
if [ -f "$METRICS_FILE" ]; then
  GW_UP=$(grep "^openclaw_gateway_up " "$METRICS_FILE" | awk '{print $2}')
  MEM_BYTES=$(grep "^openclaw_memory_bytes " "$METRICS_FILE" | awk '{print $2}')
  CPU_PCT=$(grep "^openclaw_cpu_percent " "$METRICS_FILE" | awk '{print $2}')
  UPTIME_SEC=$(grep "^openclaw_uptime_seconds " "$METRICS_FILE" | awk '{print $2}')
  HEALTH_LAT=$(grep "^openclaw_health_latency_ms " "$METRICS_FILE" | awk '{print $2}')
  DISCORD_UP=$(grep "^openclaw_discord_up " "$METRICS_FILE" | awk '{print $2}')
  CRASHES=$(grep "^openclaw_crash_count " "$METRICS_FILE" | awk '{print $2}')

  MEM_MB=$((MEM_BYTES / 1024 / 1024))
  UPTIME_H=$((UPTIME_SEC / 3600))
  UPTIME_M=$(( (UPTIME_SEC % 3600) / 60 ))

  GW_ICON="✅"; [ "$GW_UP" != "1" ] && GW_ICON="🔴"
  DC_ICON="✅"; [ "$DISCORD_UP" != "1" ] && DC_ICON="🔴"

  INFRA_SECTION="  ${GW_ICON} Gateway: $([ "$GW_UP" = "1" ] && echo "Running" || echo "DOWN") | ${DC_ICON} Discord: $([ "$DISCORD_UP" = "1" ] && echo "OK" || echo "Off")\n"
  INFRA_SECTION="${INFRA_SECTION}  💾 ${MEM_MB}MB | ⚡ ${CPU_PCT}% | 📡 ${HEALTH_LAT}ms | ⏱️ ${UPTIME_H}h${UPTIME_M}m\n"

  # 24시간 업타임 통계
  if [ -f "$HISTORY_LOG" ]; then
    DAY_AGO=$(( $(date +%s) - 86400 ))
    UPTIME_PCT=$(awk -F',' -v cutoff="$DAY_AGO" '
      NR > 1 && $1 >= cutoff { count++; if ($2 == 1) up++ }
      END { if (count > 0) printf "%.1f", (up/count)*100; else print "N/A" }
    ' "$HISTORY_LOG")
    INFRA_SECTION="${INFRA_SECTION}  📊 24h Uptime: ${UPTIME_PCT}% | Crashes: ${CRASHES}\n"
  fi
else
  INFRA_SECTION="  • 메트릭 파일 없음\n"
fi

# ============================================================================
# 5. 오늘 할 일 - Google Tasks
# ============================================================================
TASKS_SECTION=""
TASKS_OUTPUT=$("$GOG" tasks list "$TASKS_LIST_ID" --account "$GOG_ACCOUNT" 2>/dev/null || echo "")

if [ -n "$TASKS_OUTPUT" ]; then
  TASKS_SECTION=$(echo "$TASKS_OUTPUT" | grep "needsAction" | python3 -c "
import sys, re
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = re.split(r'\s{2,}', line)
    if len(parts) >= 4:
        title = parts[1].strip()[:40]
        due = parts[3].strip().split('T')[0] if len(parts) > 3 else ''
        if due and due != 'DUE':
            due_short = '/'.join(due.split('-')[1:])
            print(f'  • [ ] {title} (마감: {due_short})')
        else:
            print(f'  • [ ] {title}')
" 2>/dev/null || echo "")
  if [ -n "$TASKS_SECTION" ]; then
    TASKS_SECTION="${TASKS_SECTION}\n"
  fi
fi

if [ -z "$TASKS_SECTION" ]; then
  TASKS_SECTION="  • 할 일 없음\n"
fi

# ============================================================================
# 6. 오늘 일정 - Google Calendar
# ============================================================================
CALENDAR_SECTION=""
CAL_OUTPUT=$("$GOG" calendar list --from today --to today --account "$GOG_ACCOUNT" 2>/dev/null || echo "")

if [ -n "$CAL_OUTPUT" ] && [ "$CAL_OUTPUT" != "No events" ]; then
  while IFS= read -r line; do
    if [ -n "$line" ] && [ "$line" != "No events" ]; then
      CALENDAR_SECTION="${CALENDAR_SECTION}  • ${line}\n"
    fi
  done <<< "$CAL_OUTPUT"
fi

if [ -z "$CALENDAR_SECTION" ]; then
  CALENDAR_SECTION="  • 오늘 일정 없음\n"
fi

# ============================================================================
# 7. 블로커 감지 (auto-retry 실패 + 인프라 이상)
# ============================================================================
BLOCKER_SECTION=""

# auto-retry 연속 실패
if [ -f "$LOG_FILE" ]; then
  TODAY_FAILS=$(grep "\"$TODAY" "$LOG_FILE" 2>/dev/null | grep '"type":"failure"' | wc -l | tr -d ' ')
  if [ "$TODAY_FAILS" -ge 3 ]; then
    FAIL_TASKS=$(grep "\"$TODAY" "$LOG_FILE" 2>/dev/null | grep '"type":"failure"' | \
      python3 -c "import sys,json; [print(json.loads(l).get('context',{}).get('cron','unknown')) for l in sys.stdin]" 2>/dev/null | \
      sort | uniq -c | sort -rn | head -3)
    BLOCKER_SECTION="  • ⚠️ 오늘 ${TODAY_FAILS}건 실패 감지\n"
    while IFS= read -r line; do
      [ -n "$line" ] && BLOCKER_SECTION="${BLOCKER_SECTION}    → ${line}\n"
    done <<< "$FAIL_TASKS"
  fi
fi

# Gateway 다운
if [ -f "$METRICS_FILE" ]; then
  GW_CHECK=$(grep "^openclaw_gateway_up " "$METRICS_FILE" | awk '{print $2}')
  [ "$GW_CHECK" != "1" ] && BLOCKER_SECTION="${BLOCKER_SECTION}  • 🔴 Gateway DOWN\n"
fi

if [ -z "$BLOCKER_SECTION" ]; then
  BLOCKER_SECTION="  • 없음\n"
fi

# ============================================================================
# 메시지 조합
# ============================================================================
MESSAGE=$(printf "## ☀️ Morning Briefing - %s (%s)

**📈 시장**
%b
**✅ 어제 한 일**
%b%b
**🖥️ 시스템 상태**
%b
**📌 오늘 할 일**
%b
**📅 오늘 일정**
%b
**🚧 블로커**
%b" \
  "$TODAY" "$DAY_KR" \
  "$MARKET_SECTION" \
  "$COMMITS_SECTION" "$RETRY_SECTION" \
  "$INFRA_SECTION" \
  "$TASKS_SECTION" \
  "$CALENDAR_SECTION" \
  "$BLOCKER_SECTION")

# ============================================================================
# Discord 전송
# ============================================================================
echo "$MESSAGE"
echo ""

if [ ${#MESSAGE} -gt 1900 ]; then
  MESSAGE="${MESSAGE:0:1900}...(truncated)"
fi

if [ -z "$WEBHOOK_URL" ]; then
  echo "⚠️ DISCORD_WEBHOOK_URL이 설정되지 않음"
  exit 1
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg content "$MESSAGE" '{content: $content}')" \
  2>&1)

if [ "$RESPONSE" = "204" ] || [ "$RESPONSE" = "200" ]; then
  echo "✅ Discord 전송 완료"
else
  echo "⚠️ Discord 전송 실패 (HTTP $RESPONSE)"
fi
