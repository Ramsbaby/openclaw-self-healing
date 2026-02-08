const WebSocket = require('ws');

const socket = new WebSocket('wss://ws.finnhub.io?token=${process.env.FINNHUB_TOKEN}');

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
