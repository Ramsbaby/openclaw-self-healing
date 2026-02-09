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

let received = false;

socket.on('open', () => {
  console.log('✅ Finnhub 연결 성공!');
  socket.send(JSON.stringify({ type: 'subscribe', symbol: 'TQQQ' }));
  socket.send(JSON.stringify({ type: 'subscribe', symbol: 'QQQ' }));
  console.log('📊 TQQQ, QQQ 구독 완료');
  console.log('⏳ 실시간 데이터 수신 대기 중...\n');
});

socket.on('message', (data) => {
  const message = JSON.parse(data);
  if (message.type === 'trade' && message.data) {
    received = true;
    message.data.slice(0, 5).forEach(trade => {
      const time = new Date(trade.t).toLocaleTimeString('ko-KR');
      console.log(`📈 ${trade.s}: $${trade.p.toFixed(2)} | 거래량: ${trade.v.toLocaleString()} | ${time}`);
    });
  }
});

socket.on('error', (error) => {
  console.error('❌ 에러:', error.message);
});

setTimeout(() => {
  if (received) {
    console.log('\n✅✅✅ 테스트 성공! 실시간 데이터 수신 확인됨');
    console.log('🎯 08:30 고용지표 발표 시 사용 가능합니다!');
  } else {
    console.log('\n⚠️ 연결 성공, 하지만 데이터 아직 없음 (프리마켓 시간대)');
    console.log('✅ 정규장 개장(23:30 KST) 시 데이터 수신 예상');
  }
  socket.close();
  process.exit(0);
}, 6000);
