#!/bin/bash
# TQQQ 손익 자동 계산기
# 현재가 기준 실시간 손익 계산

set -euo pipefail

# ============================================================================
# 포지션 설정 (MEMORY.md 기준)
# ============================================================================
SHARES=142
AVG_COST=48.50
STOP_LOSS=47.00
USD_KRW=1465.09

# ============================================================================
# 현재가 조회 (캐시 우선)
# ============================================================================
CACHE_FILE="$HOME/openclaw/memory/tqqq-cache.json"
CURRENT_PRICE=""

if [[ -f "$CACHE_FILE" ]]; then
  AGE=$(( $(date +%s) - $(stat -f%m "$CACHE_FILE" 2>/dev/null || stat -c%Y "$CACHE_FILE") ))
  if (( AGE <= 300 )); then
    # 캐시에서 "현재가 (USD)" 라인의 숫자 추출
    CURRENT_PRICE=$(jq -r '.data' "$CACHE_FILE" | grep "현재가 (USD)" | grep -oE '[0-9]+\.[0-9]+')
  fi
fi

# 캐시 없으면 실시간 조회
if [[ -z "$CURRENT_PRICE" ]]; then
  CURRENT_PRICE=$(python3 -c "
import yfinance as yf
ticker = yf.Ticker('TQQQ')
print(f'{ticker.info.get(\"regularMarketPrice\", ticker.info.get(\"previousClose\", 0)):.2f}')
" 2>/dev/null || echo "0")
fi

# ============================================================================
# 손익 계산
# ============================================================================
if [[ "$CURRENT_PRICE" == "0" || -z "$CURRENT_PRICE" ]]; then
  echo "❌ 가격 조회 실패"
  exit 1
fi

# 계산 (bc 사용)
TOTAL_COST=$(echo "$SHARES * $AVG_COST" | bc)
CURRENT_VALUE=$(echo "$SHARES * $CURRENT_PRICE" | bc)
PNL_USD=$(echo "$CURRENT_VALUE - $TOTAL_COST" | bc)
PNL_PCT=$(echo "scale=2; ($CURRENT_PRICE - $AVG_COST) / $AVG_COST * 100" | bc)
PNL_KRW=$(echo "scale=0; $PNL_USD * $USD_KRW" | bc)
STOP_LOSS_DIST=$(echo "scale=2; ($CURRENT_PRICE - $STOP_LOSS) / $STOP_LOSS * 100" | bc)

# 부호 처리
if (( $(echo "$PNL_USD >= 0" | bc -l) )); then
  SIGN="+"
  EMOJI="📈"
else
  SIGN=""
  EMOJI="📉"
fi

# ============================================================================
# 출력
# ============================================================================
cat << EOF
$EMOJI **TQQQ 손익 현황**

| 항목 | 값 |
|------|-----|
| 현재가 | \$$CURRENT_PRICE |
| 평단가 | \$$AVG_COST |
| 보유 주수 | ${SHARES}주 |
| 투자금 | \$$(printf "%.2f" $TOTAL_COST) |
| 평가금 | \$$(printf "%.2f" $CURRENT_VALUE) |
| **손익 (USD)** | **${SIGN}\$$(printf "%.2f" $PNL_USD)** |
| **손익 (KRW)** | **${SIGN}₩$(printf "%'.0f" $PNL_KRW)** |
| **수익률** | **${SIGN}${PNL_PCT}%** |
| Stop-Loss 거리 | ${STOP_LOSS_DIST}% |

EOF

# 경고 메시지
if (( $(echo "$CURRENT_PRICE <= $STOP_LOSS" | bc -l) )); then
  echo "🚨 **STOP-LOSS 도달! 즉시 매도 필요!**"
elif (( $(echo "$STOP_LOSS_DIST < 3" | bc -l) )); then
  echo "⚠️ Stop-Loss 근접 주의 ($STOP_LOSS_DIST%)"
elif (( $(echo "$PNL_PCT >= 10" | bc -l) )); then
  echo "🎯 **익절 검토 구간 (+$PNL_PCT%)**"
fi
