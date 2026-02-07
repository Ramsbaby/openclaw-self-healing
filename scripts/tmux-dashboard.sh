#!/bin/bash
# OpenClaw TUI Monitoring Dashboard
# tmux 기반 멀티 패인 모니터링 대시보드
# Usage: ~/openclaw/scripts/tmux-dashboard.sh

SESSION="openclaw-monitor"
LOGDIR="$HOME/.openclaw/logs"

# 이미 세션이 있으면 attach
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "세션 '$SESSION' 이미 실행 중. attach 합니다..."
    tmux attach -t "$SESSION"
    exit 0
fi

# 새 세션 생성 (detached)
tmux new-session -d -s "$SESSION" -x 200 -y 50

# ── 패인 레이아웃 ──
# ┌──────────────┬──────────────┐
# │   macmon     │   gateway    │
# │  (시스템)    │    로그      │
# ├──────────────┼──────────────┤
# │   btop       │   watchdog   │
# │  (프로세스)  │  + err 로그  │
# └──────────────┴──────────────┘

# 패인 0: macmon (Apple Silicon 모니터링)
tmux send-keys -t "$SESSION" "macmon" C-m

# 패인 1: Gateway 로그 (오른쪽)
tmux split-window -h -t "$SESSION"
tmux send-keys -t "$SESSION" "tail -f $LOGDIR/gateway.log | sed 's/^/[GW] /'" C-m

# 패인 2: btop (왼쪽 하단)
tmux select-pane -t "$SESSION:0.0"
tmux split-window -v -t "$SESSION"
tmux send-keys -t "$SESSION" "btop --force-utf" C-m

# 패인 3: watchdog + error 로그 (오른쪽 하단)
tmux select-pane -t "$SESSION:0.1"
tmux split-window -v -t "$SESSION"
tmux send-keys -t "$SESSION" "tail -f $LOGDIR/watchdog.log $LOGDIR/gateway.err.log | sed -E 's|==> .*/([^/]+) <==|\\n── \\1 ──|'" C-m

# 상태바 커스텀
tmux set-option -t "$SESSION" status-style "bg=colour235,fg=colour136"
tmux set-option -t "$SESSION" status-left "#[fg=colour46,bold] OpenClaw "
tmux set-option -t "$SESSION" status-right "#[fg=colour75]%Y-%m-%d %H:%M #[fg=colour226]| #(uptime | awk '{print \$3,\$4}' | sed 's/,//')"
tmux set-option -t "$SESSION" status-interval 10

# 윈도우 이름
tmux rename-window -t "$SESSION" "Dashboard"

# 첫 패인 선택 (macmon)
tmux select-pane -t "$SESSION:0.0"

# attach
tmux attach -t "$SESSION"
