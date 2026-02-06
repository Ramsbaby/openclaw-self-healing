# OpenClaw Self-Healing 구축기 Part 2: 4-Tier 아키텍처 상세

## TL;DR
- Level 1-4 각 계층의 역할과 구현 방법
- Claude Code를 자동 복구 의사로 활용하는 핵심 코드
- 25초 복구를 달성한 실제 구현 상세

---

## Level 1: Watchdog (첫 번째 방어선)

가장 기본적인 프로세스 감시다. macOS LaunchAgent가 180초마다 체크한다.

```xml
<key>KeepAlive</key>
<true/>
<key>ThrottleInterval</key>
<integer>180</integer>
```

프로세스가 죽으면 자동 재시작. 단순하지만 90%의 장애는 이걸로 해결된다.

---

## Level 2: Health Check (상태 확인)

프로세스가 살아있어도 응답하지 않을 수 있다. HTTP 200 체크로 실제 동작 확인.

```bash
response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$GATEWAY_URL")
if [ "$response" != "200" ]; then
    # 3회 재시도 후 Level 3 호출
fi
```

핵심은 **3회 재시도**. 네트워크 일시 오류를 장애로 오판하지 않는다.

---

## Level 3: Claude Doctor (AI 의사)

이게 핵심이다. Claude Code를 tmux 세션에서 실행하고, 자동으로 진단 명령을 전송한다.

```bash
# tmux 세션 생성
tmux new-session -d -s "$TMUX_SESSION" "claude --dangerously-skip-permissions"

# 진단 명령 전송
tmux send-keys -t "$TMUX_SESSION" "openclaw status를 확인하고, 
로그를 분석해서 문제를 찾고, 
자동으로 복구해줘" Enter
```

Claude Code가 알아서:
1. `openclaw status` 실행
2. 로그 파일 분석
3. 설정 검증
4. 포트 충돌 확인
5. 자동 수정 시도

**30분 타임아웃** 안에 해결 못하면 Level 4로 에스컬레이션.

---

## Level 4: Discord Alert (인간 호출)

AI도 못 고치면 사람이 나선다.

```bash
curl -X POST "$DISCORD_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"🚨 OpenClaw 복구 실패! 수동 개입 필요\"}"
```

---

## 25초 복구의 비밀

실제 테스트에서 25초 복구를 달성한 이유:

1. **빠른 감지**: Health Check 5분 간격 → 문제 발생 즉시 Level 3 호출
2. **병렬 처리**: Claude Code가 여러 진단을 동시에 수행
3. **단순한 해결책 우선**: restart 먼저 시도, 복잡한 수정은 나중에

---

## 다음 글에서

Part 3에서는 실패 사례와 교훈, 그리고 이 시스템을 만들면서 배운 것들을 공유한다.

---

*GitHub: https://github.com/Ramsbaby/openclaw-self-healing*
