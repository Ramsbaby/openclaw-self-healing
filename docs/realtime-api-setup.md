# 실시간 TQQQ/QQQ 모니터링 설정 가이드

## 🚀 빠른 시작 (5분)

### 1. Finnhub API 키 발급

1. 브라우저에서 열기: https://finnhub.io/register
2. 이메일로 가입 (무료)
3. Dashboard → API Keys 섹션
4. API Key 복사

### 2. 환경변수 설정

**macOS/Linux:**
```bash
export FINNHUB_API_KEY="your_api_key_here"
```

**영구 설정 (재부팅 후에도 유지):**
```bash
echo 'export FINNHUB_API_KEY="your_api_key_here"' >> ~/.zshrc
source ~/.zshrc
```

### 3. 실시간 모니터 실행

```bash
node ~/openclaw/scripts/realtime-tqqq-monitor.js
```

## 📊 출력 예시

```
✅ Finnhub WebSocket 연결 성공!
📊 실시간 모니터링 시작...

📈 TQQQ: $46.50 | 변동: +0.87% | 거래량: 125,432 | 07:30:15
📉 QQQ: $591.20 | 변동: -0.15% | 거래량: 85,234 | 07:30:16
📈 TQQQ: $46.55 | 변동: +0.11% | 거래량: 98,765 | 07:30:18

⚠️ 경고: 손절선 2% 근접 ($46.55 vs $41.40)
```

## 🚨 자동 알림

스크립트는 자동으로 다음을 체크합니다:

### 손절선 알림
- **-10% 도달 시**: 🚨 긴급 알림
- **-8% 근접 시**: ⚠️ 경고

### 목표가 알림
- **$50 도달**: 🎯 1차 목표 (30% 매도)
- **$54 도달**: 🎯 2차 목표 (50% 매도)
- **$58 도달**: 🎯 3차 목표 (전량 매도)

## ⚙️ 설정 커스터마이징

스크립트 내 변수 수정:

```javascript
// 손절선 퍼센트
const STOP_LOSS_PERCENT = -10; // -10%

// 평단가
const avgPrice = 46; // 실제 매수가로 수정

// 목표가
const targets = [
  { price: 50, name: '1차 목표', action: '30% 매도' },
  { price: 54, name: '2차 목표', action: '50% 매도' },
  { price: 58, name: '3차 목표', action: '전량 매도' },
];
```

## 🔧 트러블슈팅

### "FINNHUB_API_KEY 환경변수가 설정되지 않았습니다"

```bash
# 환경변수 확인
echo $FINNHUB_API_KEY

# 다시 설정
export FINNHUB_API_KEY="your_key"
```

### "WebSocket Error: Unauthorized"

- API 키가 올바른지 확인
- https://finnhub.io/dashboard 에서 키 재확인

### "연결이 자주 끊김"

- 무료 티어: 60 requests/분 제한
- 연결 재시도 자동 처리됨

## 📝 유료 업그레이드 (선택)

**무료 티어 충분하지만, 필요 시:**

- **Starter Plan**: $59/월
- 300 requests/분
- 더 빠른 속도
- 우선 지원

https://finnhub.io/pricing

## 🎯 실전 사용 예시

### 고용지표 발표 (08:30)

```bash
# 터미널 1: 실시간 모니터
node ~/openclaw/scripts/realtime-tqqq-monitor.js

# 터미널 2: OpenClaw (자비스와 소통)
# Discord에서 실시간 가격 공유 불필요 - 자동 모니터링!
```

### 진입/손절 자동 알림

스크립트가 자동으로:
1. 가격 변동 실시간 출력
2. 손절선 근접 경고
3. 목표가 도달 알림

정우님은 알림만 보고 토스증권에서 실행!

## 🔄 백그라운드 실행 (선택)

```bash
# tmux 세션으로 백그라운드 실행
tmux new -s tqqq-monitor
node ~/openclaw/scripts/realtime-tqqq-monitor.js

# Detach: Ctrl+B, D
# Re-attach: tmux attach -t tqqq-monitor
```

## ✅ 체크리스트

- [ ] Finnhub 가입 완료
- [ ] API 키 발급
- [ ] 환경변수 설정
- [ ] 스크립트 실행 테스트
- [ ] 실시간 데이터 수신 확인
- [ ] 알림 동작 확인

---

**설정 완료 시간: 약 5분**
**비용: 무료 (60 requests/분)**
**지연 시간: < 1초 (실시간)**
