const WebSocket = require('ws');

// API key는 환경변수에서 가져옵니다
const token = process.env.FINNHUB_TOKEN;
if (!token) {
  console.error('❌ 에러: FINNHUB_TOKEN 환경변수가 설정되지 않았습니다.');
  console.error('설정 방법:');
  console.error('  1. Finnhub API 키 발급: https://www.finnhub.io/account/api-key');
  console.error('  2. 환경변수 설정: export FINNHUB_TOKEN=your_api_key');
  process.exit(1);
}

const socket = new WebSocket(`wss://ws.finnhub.io?token=${token}`);

console.log('⏳ Finnhub 연결 중...\n');

const prices = { TQQQ: null, QQQ: null };
let receivedCount = 0;

socket.on('open', () => {
  console.log('✅ 연결 성공!');
  socket.send(JSON.stringify({ type: 'subscribe', symbol: 'TQQQ' }));
  socket.send(JSON.stringify({ type: 'subscribe', symbol: 'QQQ' }));
  console.log('📊 TQQQ, QQQ 구독 완료\n');
  console.log('=== 실시간 가격 (최근 5개) ===\n');
});

socket.on('message', (data) => {
  const message = JSON.parse(data);
  
  if (message.type === 'trade' && message.data) {
    message.data.slice(0, 5).forEach(trade => {
      const time = new Date(trade.t).toLocaleTimeString('ko-KR', { hour12: false });
      const price = trade.p.toFixed(2);
      const symbol = trade.s;
      
      prices[symbol] = price;
      receivedCount++;
      
      console.log(`📈 ${symbol}: $${price} | ${time}`);
    });
    
    // 충분한 데이터 받으면 요약 출력
    if (receivedCount >= 10) {
      console.log('\n=== 현재 가격 요약 ===');
      if (prices.TQQQ) console.log(`TQQQ: $${prices.TQQQ}`);
      if (prices.QQQ) console.log(`QQQ: $${prices.QQQ}`);
      console.log('\n✅ 토스증권 가격과 비교해보세요!');
      console.log('(차이가 $0.10 이내면 정상입니다)\n');
      
      socket.close();
      process.exit(0);
    }
  }
});

socket.on('error', (error) => {
  console.error('❌ 에러:', error.message);
});

// 15초 후 자동 종료
setTimeout(() => {
  console.log('\n=== 현재까지 받은 가격 ===');
  if (prices.TQQQ) {
    console.log(`TQQQ: $${prices.TQQQ}`);
  } else {
    console.log('TQQQ: 데이터 없음 (프리마켓 거래 없음)');
  }
  
  if (prices.QQQ) {
    console.log(`QQQ: $${prices.QQQ}`);
  } else {
    console.log('QQQ: 데이터 없음 (프리마켓 거래 없음)');
  }
  
  console.log('\n💡 프리마켓 시간대는 거래가 적어 데이터가 적을 수 있습니다.');
  console.log('✅ 정규장 개장(23:30 KST) 시 활발한 데이터 수신 예상');
  
  socket.close();
  process.exit(0);
}, 15000);
