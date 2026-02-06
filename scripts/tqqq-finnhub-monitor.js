#!/usr/bin/env node

/**
 * TQQQ Finnhub 24/7 모니터링 시스템
 * 
 * Finnhub WebSocket으로 실시간 모니터링
 * Stop-Loss: $47.00 (환경변수로 변경 가능)
 */

const WebSocket = require('ws');
const { exec } = require('child_process');

// 환경변수
const FINNHUB_API_KEY = process.env.FINNHUB_API_KEY || '';
const STOP_LOSS_PRICE = parseFloat(process.env.TQQQ_STOP_LOSS || '47.00');
const TICKER = 'TQQQ';
const DISCORD_CHANNEL = '1469190686145384513'; // #jarvis-market

// 상태
let lastPrice = null;
let alertSent = false;
let consecutiveBreaches = 0;
const BREACH_THRESHOLD = 3;
let lastAlertTime = 0;
const ALERT_COOLDOWN = 300000; // 5분

/**
 * Stop-Loss 체크
 */
function checkStopLoss(price) {
  const now = Date.now();
  lastPrice = price;
  
  if (price < STOP_LOSS_PRICE) {
    consecutiveBreaches++;
    console.log(`⚠️  Price: $${price.toFixed(2)} | Stop-Loss: $${STOP_LOSS_PRICE} | Breaches: ${consecutiveBreaches}/${BREACH_THRESHOLD}`);
    
    if (consecutiveBreaches >= BREACH_THRESHOLD && !alertSent && (now - lastAlertTime) > ALERT_COOLDOWN) {
      sendDiscordAlert(price);
      alertSent = true;
      lastAlertTime = now;
    }
  } else {
    if (consecutiveBreaches > 0) {
      console.log(`✅ Price recovered: $${price.toFixed(2)}`);
      consecutiveBreaches = 0;
      alertSent = false;
    }
  }
}

/**
 * Discord 알림
 */
function sendDiscordAlert(price) {
  const kstTime = new Date().toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });
  const krwPrice = Math.round(price * 1465.09); // USD to KRW
  const message = `🚨 **TQQQ Stop-Loss 트리거**

**현재가:** $${price.toFixed(2)} (₩${krwPrice.toLocaleString('ko-KR')})
**손절선:** $${STOP_LOSS_PRICE.toFixed(2)}
**시각:** ${kstTime}

⚠️ 즉시 확인 필요!`;

  // Use message tool via Node.js (direct API call)
  const https = require('https');
  const payload = JSON.stringify({
    action: 'send',
    channel: 'discord',
    target: `channel:${DISCORD_CHANNEL}`,
    message: message
  });

  const options = {
    hostname: 'localhost',
    port: 18789,
    path: '/rpc',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(payload)
    }
  };

  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
      if (res.statusCode === 200) {
        console.log('✅ Discord 알림 전송 완료');
      } else {
        console.error(`❌ Discord 알림 실패: ${res.statusCode} ${data}`);
      }
    });
  });

  req.on('error', (error) => {
    console.error(`❌ Discord 알림 실패: ${error.message}`);
  });

  req.write(JSON.stringify({
    jsonrpc: '2.0',
    id: Date.now(),
    method: 'tools/call',
    params: {
      name: 'message',
      arguments: {
        action: 'send',
        channel: 'discord',
        target: `channel:${DISCORD_CHANNEL}`,
        message: message
      }
    }
  }));
  req.end();
}

/**
 * Finnhub WebSocket
 */
function startWebSocket() {
  console.log('🔌 Finnhub WebSocket 연결 시작...');
  
  const ws = new WebSocket(`wss://ws.finnhub.io?token=${FINNHUB_API_KEY}`);
  
  ws.on('open', () => {
    console.log('✅ Finnhub WebSocket 연결됨');
    ws.send(JSON.stringify({ type: 'subscribe', symbol: TICKER }));
    console.log(`📡 ${TICKER} 구독 시작`);
    console.log(`🛑 Stop-Loss: $${STOP_LOSS_PRICE.toFixed(2)}`);
  });
  
  ws.on('message', (data) => {
    const message = JSON.parse(data);
    
    if (message.type === 'trade' && message.data && message.data.length > 0) {
      message.data.forEach(trade => {
        checkStopLoss(trade.p);
      });
    }
  });
  
  ws.on('error', (error) => {
    console.error(`❌ WebSocket 에러: ${error.message}`);
  });
  
  ws.on('close', () => {
    console.log('🔌 WebSocket 연결 종료');
    console.log('🔄 5초 후 재연결...');
    setTimeout(startWebSocket, 5000);
  });
  
  return ws;
}

// 시작
console.log('🚀 TQQQ Finnhub 24/7 모니터링');
console.log(`📊 Ticker: ${TICKER}`);
console.log(`🛑 Stop-Loss: $${STOP_LOSS_PRICE.toFixed(2)}`);
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

if (!FINNHUB_API_KEY) {
  console.error('❌ FINNHUB_API_KEY 환경변수 필요');
  process.exit(1);
}

startWebSocket();
