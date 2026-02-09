# n8n 계정 정보

> ⚠️ **보안 주의:** 이 파일은 민감한 정보를 포함합니다.

## 접속 정보

- **URL (로컬):** http://localhost:5678
- **URL (원격):** http://macmini.tail75f63b.ts.net:5678
- **Email:** your-email@example.com
- **이름:** Jarvis Assistant
- **비밀번호:** (웹 UI에서 설정한 값 — 정우님만 알고 있음)

## Docker 관리

```bash
# 시작
docker start n8n

# 중지
docker stop n8n

# 로그 확인
docker logs n8n --tail 50

# 상태 확인
docker ps | grep n8n
```

## 데이터 위치

- **설정:** `~/.n8n/config`
- **DB:** `~/.n8n/database.sqlite`
- **Encryption Key:** `~/.n8n/config` 내 `encryptionKey` 필드

## 버전 정보

- **n8n:** 2.6.4
- **Node:** 22.22.0
- **Runner:** JS Task Runner (w5N0GQHtcAmMVtXfjPhHv)

## 주의사항

1. Python Task Runner는 비활성화됨 (Python 3 미설치)
2. 외부 접근 시 Tailscale 필요 (보안)
3. `util._extend` 경고는 무시해도 됨 (deprecated 경고)
