#!/usr/bin/env node

/**
 * TQQQ 하이브리드 모니터링 시스템
 * 
 * 정규장 (09:30-16:00 EST): Finnhub WebSocket (실시간)
 * 확장 시간 (04:00-09:30, 16:00-20:00 EST): Polygon API (1분 폴링)
 * 
 * Stop-Loss: $47.00
 */

const WebSocket = require('ws');
const https = require('https');
const { exec } = require('child_process');

// 환경변수 로드
const FINNHUB_API_KEY = process.env.FINNHUB_API_KEY || '';
const POLYGON_API_KEY = process.env.POLYGON_API_KEY || '';
const STOP_LOSS_PRICE = parseFloat(process.env.TQQQ_STOP_LOSS || '47.00');
const TICKER = 'TQQQ';

// Discord 알림 설정
const DISCORD_CHANNEL = '1468429321738911947'; // #jarvis-health

// 상태 관리
let lastPrice = null;
let alertSent = false;
let consecutiveBreaches = 0;
const BREACH_THRESHOLD = 3; // 3회 연속 확인 후 알림

/**
 * 현재 시간이 정규장인지 확인 (EST 기준)
 */
function isMarketHours() {
  const now = new Date();
  const estOffset = -5 * 60; // EST = UTC-5
  const estTime = new Date(now.getTime() + (estOffset + now.getTimezoneOffset()) * 60000);
  
  const day = estTime.getDay(); // 0=일, 6=토
  const hour = estTime.getHours();
  const minute = estTime.getMinutes();
  const totalMinutes = hour * 60 + minute;
  
  // 주말 제외
  if (day === 0 || day === 6) return false;
  
  // 정규장: 09:30 - 16:00 EST
  const marketOpen = 9 * 60 + 30;  // 09:30
  const marketClose = 16 * 60;      // 16:00
  
  return totalMinutes >= marketOpen && totalMinutes < marketClose;
}

/**
 * 확장 시간인지 확인 (프리마켓 + 애프터마켓)
 */
function isExtendedHours() {
  const now = new Date();
  const estOffset = -5 * 60;
  const estTime = new Date(now.getTime() + (estOffset + now.getTimezoneOffset()) * 60000);
  
  const day = estTime.getDay();
  const hour = estTime.getHours();
  const minute = estTime.getMinutes();
  const totalMinutes = hour * 60 + minute;
  
  // 주말 제외
  if (day === 0 || day === 6) return false;
  
  // 프리마켓: 04:00 - 09:30 EST
  const premarketStart = 4 * 60;
  const premarketEnd = 9 * 60 + 30;
  
  // 애프터마켓: 16:00 - 20:00 EST
  const aftermarketStart = 16 * 60;
  const aftermarketEnd = 20 * 60;
  
  return (totalMinutes >= premarketStart && totalMinutes < premarketEnd) ||
         (totalMinutes >= aftermarketStart && totalMinutes < aftermarketEnd);
}

/**
 * Stop-Loss 체크 및 알림
 */
function checkStopLoss(price, source) {
  lastPrice = price;
  
  if (price < STOP_LOSS_PRICE) {
    consecutiveBreaches++;
    console.log(`⚠️ [${source}] Price: $${price.toFixed(2)} | Stop-Loss: $${STOP_LOSS_PRICE} | Breaches: ${consecutiveBreaches}/${BREACH_THRESHOLD}`);
    
    if (consecutiveBreaches >= BREACH_THRESHOLD && !alertSent) {
      sendDiscordAlert(price, source);
      alertSent = true;
    }
  } else {
    if (consecutiveBreaches > 0) {
      console.log(`✅ [${source}] Price recovered: $${price.toFixed(2)}`);
    }
    consecutiveBreaches = 0;
  }
}

/**
 * Discord 알림 전송
 */
function sendDiscordAlert(price, source) {
  const message = `🚨 **TQQQ Stop-Loss 트리거**

**현재가:** $${price.toFixed(2)}
**손절선:** $${STOP_LOSS_PRICE.toFixed(2)}
**소스:** ${source}
**시각:** ${new Date().toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' })}

⚠️ 즉시 확인 필요!`;

  const cmd = `message action:send channel:discord target:"${DISCORD_CHANNEL}" message:"${message.replace(/"/g, '\\"')}"`;
  
  exec(`openclaw ${cmd}`, (error, stdout, stderr) => {
    if (error) {
      console.error(`❌ Discord 알림 실패: ${error.message}`);
    } else {
      console.log('✅ Discord 알림 전송 완료');
    }
  });
}

/**
 * Finnhub WebSocket (정규장)
 */
function startFinnhubWebSocket() {
  console.log('🔌 Finnhub WebSocket 연결 시작...');
  
  const ws = new WebSocket(`wss://ws.finnhub.io?token=${FINNHUB_API_KEY}`);
  
  ws.on('open', () => {
    console.log('✅ Finnhub WebSocket 연결됨');
    ws.send(JSON.stringify({ type: 'subscribe', symbol: TICKER }));
    console.log(`📡 ${TICKER} 구독 시작`);
  });
  
  ws.on('message', (data) => {
    const message = JSON.parse(data);
    
    if (message.type === 'trade' && message.data && message.data.length > 0) {
      const trades = message.data;
      trades.forEach(trade => {
        const price = trade.p;
        checkStopLoss(price, 'Finnhub WebSocket');
      });
    }
  });
  
  ws.on('error', (error) => {
    console.error(`❌ Finnhub WebSocket 에러: ${error.message}`);
  });
  
  ws.on('close', () => {
    console.log('🔌 Finnhub WebSocket 연결 종료');
    // 정규장 시간이면 재연결
    if (isMarketHours()) {
      console.log('🔄 5초 후 재연결...');
      setTimeout(startFinnhubWebSocket, 5000);
    }
  });
  
  return ws;
}

/**
 * Polygon API 폴링 (확장 시간)
 */
function pollPolygonAPI() {
  const url = `https://api.polygon.io/v2/last/trade/${TICKER}?apiKey=${POLYGON_API_KEY}`;
  
  https.get(url, (res) => {
    let data = '';
    
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      try {
        const json = JSON.parse(data);
        
        if (json.status === 'OK' && json.results && json.results.p) {
          const price = json.results.p;
          checkStopLoss(price, 'Polygon API');
        } else {
          console.error(`❌ Polygon API 에러: ${json.error || 'Unknown'}`);
        }
      } catch (error) {
        console.error(`❌ JSON 파싱 에러: ${error.message}`);
      }
    });
  }).on('error', (error) => {
    console.error(`❌ Polygon API 요청 실패: ${error.message}`);
  });
}

/**
 * 메인 루프
 */
function main() {
  console.log('🚀 TQQQ 하이브리드 모니터링 시작');
  console.log(`📊 Ticker: ${TICKER}`);
  console.log(`🛑 Stop-Loss: $${STOP_LOSS_PRICE.toFixed(2)}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  // API 키 검증
  if (!FINNHUB_API_KEY) {
    console.error('❌ FINNHUB_API_KEY 환경변수 필요');
    process.exit(1);
  }
  
  if (!POLYGON_API_KEY) {
    console.error('❌ POLYGON_API_KEY 환경변수 필요');
    process.exit(1);
  }
  
  let currentMode = null;
  let ws = null;
  let pollingInterval = null;
  
  // 1분마다 모드 체크 및 전환
  setInterval(() => {
    const isMarket = isMarketHours();
    const isExtended = isExtendedHours();
    
    if (isMarket && currentMode !== 'market') {
      console.log('\n🔔 정규장 시작 → Finnhub WebSocket 모드');
      currentMode = 'market';
      
      // Polygon 폴링 중지
      if (pollingInterval) {
        clearInterval(pollingInterval);
        pollingInterval = null;
      }
      
      // Finnhub WebSocket 시작
      ws = startFinnhubWebSocket();
      
    } else if (isExtended && currentMode !== 'extended') {
      console.log('\n🔔 확장 시간 시작 → Polygon 폴링 모드');
      currentMode = 'extended';
      
      // Finnhub WebSocket 중지
      if (ws) {
        ws.close();
        ws = null;
      }
      
      // Polygon 폴링 시작 (1분마다)
      pollingInterval = setInterval(pollPolygonAPI, 60000);
      pollPolygonAPI(); // 즉시 1회 실행
      
    } else if (!isMarket && !isExtended && currentMode !== 'closed') {
      console.log('\n🔔 장 마감 → 대기 모드');
      currentMode = 'closed';
      
      // 모든 모니터링 중지
      if (ws) {
        ws.close();
        ws = null;
      }
      if (pollingInterval) {
        clearInterval(pollingInterval);
        pollingInterval = null;
      }
      
      // 알림 상태 리셋
      alertSent = false;
      consecutiveBreaches = 0;
    }
  }, 60000); // 1분마다 체크
  
  // 초기 모드 설정
  if (isMarketHours()) {
    currentMode = 'market';
    ws = startFinnhubWebSocket();
  } else if (isExtendedHours()) {
    currentMode = 'extended';
    pollingInterval = setInterval(pollPolygonAPI, 60000);
    pollPolygonAPI();
  } else {
    currentMode = 'closed';
    console.log('⏸️ 현재 장 마감 시간 (대기 중)');
  }
}

// 프로그램 시작
main();
