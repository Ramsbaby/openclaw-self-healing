#!/bin/bash
# OpenClaw Dashboard - Detached 모드로 tmux 대시보드 세션 생성
# LaunchAgent에서 로그인 시 자동 호출
# 수동 실행: ~/openclaw/scripts/start-dashboard.sh
# 접속: tmux attach -t openclaw-monitor
#
# 레이아웃:
# ┌──────────────┬──────────────┐
# │   macmon     │   gateway    │
# │  (시스템)    │    로그      │
# ├──────────────┼──────────────┤
# │   btop       │   watchdog   │
# │  (프로세스)  │  + err 로그  │
# └──────────────┴──────────────┘

SESSION="openclaw-monitor"
LOGDIR="$HOME/.openclaw/logs"
TMUX="/opt/homebrew/bin/tmux"

# 이미 세션이 있으면 스킵
if $TMUX has-session -t "$SESSION" 2>/dev/null; then
    echo "$(date): 세션 '$SESSION' 이미 실행 중. 스킵." >> "$LOGDIR/dashboard.stdout.log"
    exit 0
fi

# 잠시 대기 (로그인 직후 안정화)
sleep 3

# 로그 파일 없으면 생성
touch "$LOGDIR/gateway.log" "$LOGDIR/watchdog.log" "$LOGDIR/gateway.err.log"

# 새 세션 생성 - 각 패인에 명령어를 직접 넘기는 방식
# 패인 0: macmon (좌상단)
$TMUX new-session -d -s "$SESSION" -x 200 -y 50 "macmon; bash"

# 패인 1: Gateway 로그 (우상단) - 세로 분할
$TMUX split-window -h -t "$SESSION:0.0" "tail -f $LOGDIR/gateway.log; bash"

# 패인 2: btop (좌하단) - 좌상단을 가로 분할
$TMUX split-window -v -t "$SESSION:0.0" "btop --force-utf; bash"

# 패인 3: watchdog + error 로그 (우하단) - 우상단을 가로 분할
$TMUX split-window -v -t "$SESSION:0.1" "tail -f $LOGDIR/watchdog.log $LOGDIR/gateway.err.log; bash"

# 상태바 커스텀
$TMUX set-option -t "$SESSION" status-style "bg=colour235,fg=colour136"
$TMUX set-option -t "$SESSION" status-left "#[fg=colour46,bold] OpenClaw "
$TMUX set-option -t "$SESSION" status-right "#[fg=colour75]%Y-%m-%d %H:%M"
$TMUX set-option -t "$SESSION" status-interval 10
$TMUX rename-window -t "$SESSION" "Dashboard"

# macmon 패인으로 포커스
$TMUX select-pane -t "$SESSION:0.0"

echo "$(date): Dashboard 세션 시작 완료 (4패인)" >> "$LOGDIR/dashboard.stdout.log"
