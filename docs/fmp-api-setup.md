# FMP API 설정 가이드

## Institutional Flow Tracker 사용을 위한 필수 설정

### 1. FMP 무료 계정 생성
1. https://financialmodelingprep.com/developer/docs 접속
2. "Get Your Free API Key" 클릭
3. 이메일/비밀번호로 회원가입
4. Dashboard에서 API Key 복사

### 2. API Key 환경변수 설정

**방법 1: openclaw.json에 추가 (권장)**
```bash
# 현재 설정 백업
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak

# openclaw.json 편집
# env.vars 섹션에 추가:
# "FMP_API_KEY": "your_api_key_here"
```

**방법 2: 쉘 환경변수**
```bash
# ~/.zshrc 또는 ~/.bashrc에 추가
echo 'export FMP_API_KEY="your_api_key_here"' >> ~/.zshrc
source ~/.zshrc
```

### 3. 확인
```bash
echo $FMP_API_KEY
# 또는
uv run ~/openclaw/skills/institutional-flow-tracker/scripts/track_institutional_flow.py --test
```

### 4. Free Tier 제한
- **250 requests/day** (주간 리포트용으로 충분)
- 13F 데이터: 분기별 업데이트 (45일 지연)
- Rate limit: 300 requests/minute

## 사용 예시
```bash
# QQQ 기관 보유 추적
uv run ~/openclaw/skills/institutional-flow-tracker/scripts/track_institutional_flow.py QQQ

# 여러 종목 비교
uv run ~/openclaw/skills/institutional-flow-tracker/scripts/track_institutional_flow.py QQQ SPY AAPL
```
