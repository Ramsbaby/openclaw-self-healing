#!/usr/bin/env node

/**
 * Finnhub 실시간 TQQQ/QQQ 모니터
 * Usage: FINNHUB_API_KEY=your_key node realtime-tqqq-monitor.js
 */

const WebSocket = require('ws');

// API key는 환경변수에서 가져옵니다
const FINNHUB_API_KEY = process.env.FINNHUB_API_KEY || process.env.FINNHUB_TOKEN;

if (!FINNHUB_API_KEY) {
  console.error('❌ 에러: FINNHUB API 키가 설정되지 않았습니다.');
  console.error('');
  console.error('설정 방법:');
  console.error('  1. Finnhub API 키 발급: https://www.finnhub.io/account/api-key');
  console.error('  2. 환경변수 설정:');
  console.error('     export FINNHUB_API_KEY=your_api_key');
  console.error('     또는');
  console.error('     export FINNHUB_TOKEN=your_api_key');
  console.error('');
  process.exit(1);
}

const socket = new WebSocket(`wss://ws.finnhub.io?token=${FINNHUB_API_KEY}`);

const prices = {
  TQQQ: null,
  QQQ: null,
};

const STOP_LOSS_PERCENT = -10; // -10% 손절선
let initialPortfolio = 9000; // $9,000

socket.on('open', () => {
  console.log('✅ Finnhub WebSocket 연결 성공!');
  console.log('📊 실시간 모니터링 시작...\n');
  
  // TQQQ, QQQ 구독
  socket.send(JSON.stringify({ type: 'subscribe', symbol: 'TQQQ' }));
  socket.send(JSON.stringify({ type: 'subscribe', symbol: 'QQQ' }));
});

socket.on('message', (data) => {
  try {
    const message = JSON.parse(data);
    
    if (message.type === 'trade' && message.data) {
      message.data.forEach(trade => {
        const symbol = trade.s;
        const price = trade.p;
        const volume = trade.v;
        const timestamp = new Date(trade.t).toLocaleTimeString('ko-KR');
        
        // 가격 업데이트
        if (symbol === 'TQQQ' || symbol === 'QQQ') {
          const prevPrice = prices[symbol];
          prices[symbol] = price;
          
          const change = prevPrice ? ((price - prevPrice) / prevPrice * 100).toFixed(2) : '0.00';
          const changeIcon = parseFloat(change) >= 0 ? '📈' : '📉';
          
          console.log(`${changeIcon} ${symbol}: $${price.toFixed(2)} | 변동: ${change}% | 거래량: ${volume.toLocaleString()} | ${timestamp}`);
          
          // 손절선 체크 (TQQQ만)
          if (symbol === 'TQQQ') {
            checkStopLoss(price);
            checkTargets(price);
          }
        }
      });
    }
  } catch (error) {
    console.error('❌ Error parsing message:', error.message);
  }
});

socket.on('error', (error) => {
  console.error('❌ WebSocket Error:', error.message);
});

socket.on('close', () => {
  console.log('🔌 WebSocket 연결 종료');
});

// 손절선 체크
function checkStopLoss(currentPrice) {
  // 예시: $46 평단가 기준
  const avgPrice = 46;
  const stopLossPrice = avgPrice * (1 + STOP_LOSS_PERCENT / 100);
  const currentLoss = ((currentPrice - avgPrice) / avgPrice * 100).toFixed(2);
  
  if (currentPrice <= stopLossPrice) {
    console.log('\n🚨🚨🚨 손절선 터짐! 🚨🚨🚨');
    console.log(`현재가: $${currentPrice.toFixed(2)}`);
    console.log(`손절선: $${stopLossPrice.toFixed(2)}`);
    console.log(`손실: ${currentLoss}%`);
    console.log('⚠️ 즉시 전량 매도 필요!\n');
  } else if (currentPrice <= stopLossPrice * 1.02) {
    console.log(`\n⚠️ 경고: 손절선 2% 근접 ($${currentPrice.toFixed(2)} vs $${stopLossPrice.toFixed(2)})\n`);
  }
}

// 목표가 체크
function checkTargets(currentPrice) {
  const avgPrice = 46;
  const targets = [
    { price: 50, name: '1차 목표', action: '30% 매도' },
    { price: 54, name: '2차 목표 (복구)', action: '50% 매도' },
    { price: 58, name: '3차 목표', action: '전량 매도' },
  ];
  
  targets.forEach(target => {
    if (currentPrice >= target.price && currentPrice <= target.price * 1.01) {
      const profit = ((currentPrice - avgPrice) / avgPrice * 100).toFixed(2);
      console.log(`\n🎯 ${target.name} 도달!`);
      console.log(`현재가: $${currentPrice.toFixed(2)} | 수익: +${profit}%`);
      console.log(`액션: ${target.action}\n`);
    }
  });
}

// Ctrl+C로 종료 시
process.on('SIGINT', () => {
  console.log('\n👋 모니터링 종료...');
  socket.close();
  process.exit(0);
});
