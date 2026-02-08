# OpenClaw 시스템 지식

## 설정 위치
- Config: `~/.openclaw/openclaw.json`
- MCP: `~/.mcp.json`
- Workspace: `~/openclaw`

## 크론 관리
- 전체 17개 활성
- 모델: Haiku (anthropic/claude-haiku-4-5-20251001)
- 토큰 절약 위해 Haiku 사용

## 주요 크론 목록
- 06:00 Daily Stock Briefing
- 06:15 모닝 브리핑
- 07:55 조식 알림
- 09:00/12:00/15:00/18:00/21:00 시간당 종합 체크
- 12:00 IT/AI 뉴스 브리핑
- 12:30/20:30 Trend Hunter
- 15 */1h GitHub Watcher
- 17:00 Daily Wrap-up
- 19:00 관훈 미확정 저녁
- 22:00 부부 약 먹기 알림
- 22:30 크론 감시 리포트
- 23:00 일일 자가개선
- 23:00~05:00 Market Vol Watch (30분마다)
- 23:50 야간 종합 점검
- 00:00 취침 알림
- 매월 25일 DCA Reminder
- 월요일 08:00 실적 발표 캘린더

## 모델 별칭
- opus: claude-opus-4-5
- sonnet: claude-sonnet-4/4-5
- haiku: claude-haiku-4-5-20251001
- gemini-3: gemini-3-pro-preview (구독 다운그레이드로 미사용)
- flash: gemini-1.5-flash (구독 다운그레이드로 미사용)

## MCP 서버 (7개)
1. Brave Search
2. GitHub
3. Filesystem (openclaw + clawd)
4. Memory
5. Puppeteer
6. Moltbot Docs
7. Clawdbot Docs

## 주요 스킬
- yahoo-finance: yf 스크립트 (직접 작성)
- github-watcher: check.sh
- stock-analysis
- gog (Google Workspace)

## 최근 해결한 문제
- exec 보안: allowlist → full
- yahoo-finance yf 스크립트 복구
- 크론 모델 에러: haiku 별칭 추가
- 실종 크론 11개 복구
- CodexBar 설치

## Claude 사용량 조회 프로토콜
1. `claude` PTY 실행
2. 워크스페이스 신뢰 (Enter)
3. `/usage` 입력
4. 파싱
5. Escape + 종료
