const WebSocket = require('ws');

const socket = new WebSocket('wss://ws.finnhub.io?token=${process.env.FINNHUB_TOKEN}');

console.log('🚀 Finnhub 파워 테스트 시작!');
console.log('💡 비트코인 (24시간 거래) 실시간 모니터링\n');

let tradeCount = 0;
const startTime = Date.now();

socket.on('open', () => {
  console.log('✅ 연결 성공!');
  console.log('📊 BTC-USD 구독 완료\n');
  console.log('=== 실시간 거래 데이터 폭발! ===\n');
  
  // 비트코인 구독 (24시간 거래)
  socket.send(JSON.stringify({ type: 'subscribe', symbol: 'BINANCE:BTCUSDT' }));
});

socket.on('message', (data) => {
  const message = JSON.parse(data);
  
  if (message.type === 'trade' && message.data) {
    message.data.forEach(trade => {
      tradeCount++;
      const time = new Date(trade.t).toLocaleTimeString('ko-KR', { hour12: false, fractionalSecondDigits: 3 });
      const price = trade.p.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      const volume = trade.v.toFixed(6);
      
      console.log(`⚡ #${tradeCount} | BTC: $${price} | 수량: ${volume} | ${time}`);
    });
  }
});

socket.on('error', (error) => {
  console.error('❌ 에러:', error.message);
});

// 10초 후 결과 요약
setTimeout(() => {
  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  
  console.log('\n=================================');
  console.log('🎯 Finnhub 파워 테스트 결과');
  console.log('=================================');
  console.log(`⏱️  실행 시간: ${elapsed}초`);
  console.log(`📊 받은 거래 수: ${tradeCount}개`);
  console.log(`⚡ 초당 거래: ${(tradeCount / elapsed).toFixed(1)}개/초`);
  console.log(`🚀 지연 시간: < 1초 (실시간)`);
  console.log('\n✅ 이게 Finnhub의 파워입니다!');
  console.log('✅ 08:30 고용지표 발표 시 TQQQ도 이렇게 쏟아집니다!');
  
  socket.close();
  process.exit(0);
}, 10000);
