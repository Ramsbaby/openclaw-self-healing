#!/bin/bash
# Claude 주간 한도만 간단히 조회

SESSION_NAME="claude-usage-$$"

# tmux 세션 생성
tmux new-session -d -s "$SESSION_NAME" "claude" 2>/dev/null || {
  echo "⚠️ tmux 세션 생성 실패"
  exit 1
}

# workspace trust 확인 (Enter)
sleep 3
tmux send-keys -t "$SESSION_NAME" "" Enter

# /usage 입력
sleep 2
tmux send-keys -t "$SESSION_NAME" "/usage" Enter

# 한 번 더 Enter (UI 렌더링 트리거)
sleep 1
tmux send-keys -t "$SESSION_NAME" "" Enter

# 결과 대기 (UI 렌더링 시간)
sleep 4

# 캡처 (전체 화면)
USAGE_OUTPUT=$(tmux capture-pane -t "$SESSION_NAME" -p -S -100 2>/dev/null)

# 세션 종료
tmux send-keys -t "$SESSION_NAME" "Escape" 2>/dev/null
sleep 0.5
tmux kill-session -t "$SESSION_NAME" 2>/dev/null

# 파싱: "Current week (all models)" 다음 줄에서 "% used" 찾기
PERCENT_USED=$(echo "$USAGE_OUTPUT" | grep "Current week (all models)" -A 2 | grep -oE "[0-9]+% used" | head -1)

# "Resets" 날짜 찾기 (Current week 라인 포함 3줄)
RESET_DATE=$(echo "$USAGE_OUTPUT" | grep "Current week (all models)" -A 2 | grep "Resets" | sed 's/.*Resets //' | sed 's/ (Asia\/Seoul)//' | head -1)

if [[ -n "$PERCENT_USED" ]]; then
  # 남은 % 계산
  USED_NUM=$(echo "$PERCENT_USED" | grep -oE "[0-9]+")
  REMAINING=$((100 - USED_NUM))
  
  echo "사용: ${PERCENT_USED}, 남은: ${REMAINING}%, 리셋: ${RESET_DATE}"
else
  echo "⚠️ 조회 실패"
fi
