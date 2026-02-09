#!/bin/bash

# Polygon.io Quote API 테스트 스크립트
# 사용법: ./polygon-quote-test.sh POLYGON_API_KEY

API_KEY="$1"

if [ -z "$API_KEY" ]; then
  echo "❌ Usage: $0 POLYGON_API_KEY"
  exit 1
fi

TICKER="TQQQ"

echo "🔍 Polygon.io Quote API 테스트"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Last Trade 조회
echo ""
echo "📊 Last Trade:"
curl -s "https://api.polygon.io/v2/last/trade/${TICKER}?apiKey=${API_KEY}" | jq -r '
  if .status == "OK" then
    "✅ Price: $\(.results.p) | Size: \(.results.s) | Time: \(.results.t)"
  else
    "❌ Error: \(.error // "Unknown")"
  end
'

# Last Quote 조회 (bid/ask)
echo ""
echo "💰 Last Quote (Bid/Ask):"
curl -s "https://api.polygon.io/v2/last/nbbo/${TICKER}?apiKey=${API_KEY}" | jq -r '
  if .status == "OK" then
    "✅ Bid: $\(.results.P) x \(.results.S) | Ask: $\(.results.p) x \(.results.s)"
  else
    "❌ Error: \(.error // "Unknown")"
  end
'

# Snapshot 조회 (종합 정보)
echo ""
echo "📸 Snapshot:"
curl -s "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers/${TICKER}?apiKey=${API_KEY}" | jq -r '
  if .status == "OK" then
    .ticker |
    "✅ Last: $\(.day.c) | Volume: \(.day.v) | Change: \(.todaysChangePerc)%"
  else
    "❌ Error: \(.error // "Unknown")"
  end
'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 테스트 완료"
