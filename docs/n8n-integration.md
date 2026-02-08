# n8n + OpenClaw 연동 가이드

## 개요

n8n은 셀프호스팅 가능한 워크플로우 자동화 플랫폼입니다.
OpenClaw와 연동하면 복잡한 멀티스텝 자동화를 구현할 수 있습니다.

## 접속 정보

- **로컬**: http://localhost:5678
- **원격**: http://macmini.tail75f63b.ts.net:5678
- **버전**: 2.6.4

## Docker 관리

### 시작/중지

```bash
# 시작
docker start n8n

# 중지
docker stop n8n

# 재시작
docker restart n8n

# 로그 확인
docker logs n8n --tail 50
```

### 데이터 위치

- 설정/워크플로우: `~/.n8n/`
- 백업 시 이 폴더 복사

## 활용 예시

### 1. 이메일 → 요약 → Discord

1. Gmail 노드: 새 이메일 트리거
2. OpenAI 노드: 이메일 내용 요약
3. Discord Webhook 노드: #jarvis에 전송

### 2. RSS → 오디오 브리핑

1. RSS Feed 노드: 기술 블로그 피드
2. Code 노드: 본문 추출 및 정리
3. HTTP Request 노드: OpenAI TTS API 호출
4. Telegram/Signal 노드: 오디오 파일 전송

### 3. 정기 보고서 자동화

1. Schedule 노드: 매일 오전 9시
2. HTTP Request 노드: 여러 API 데이터 수집
3. Code 노드: 데이터 정리 및 포맷
4. Discord Webhook 노드: 리포트 전송

## OpenClaw Webhook 연동

n8n에서 OpenClaw로 메시지 전송:

1. n8n에서 HTTP Request 노드 추가
2. Method: POST
3. URL: http://localhost:18789/api/message (또는 Gateway URL)
4. Body: `{"message": "n8n에서 보낸 메시지"}`

## 주의사항

- n8n은 메모리 약 200-500MB 사용
- 복잡한 워크플로우 많으면 리소스 증가
- 정기적으로 `docker stats n8n`으로 모니터링

## 참고 자료

- n8n 공식 문서: https://docs.n8n.io/
- 템플릿 라이브러리: https://n8n.io/workflows/
