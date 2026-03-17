#!/usr/bin/env bash
# ============================================================
# demo-recording.sh — OpenClaw Self-Healing 터미널 데모
# asciinema / terminalizer 등으로 녹화하기 좋게 설계됨
# 실제 서비스에 영향 없이 시뮬레이션만 수행
# ============================================================

set -euo pipefail

# ── 색상 정의 ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── 헬퍼 함수 ────────────────────────────────────────────────
type_text() {
  local text="$1"
  local delay="${2:-0.05}"
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:$i:1}"
    sleep "$delay"
  done
  echo
}

print_separator() {
  echo -e "${DIM}────────────────────────────────────────────────────────────${RESET}"
}

print_header() {
  local title="$1"
  echo
  print_separator
  echo -e "${BOLD}${CYAN}  $title${RESET}"
  print_separator
  echo
}

prompt_line() {
  echo -ne "${GREEN}❯${RESET} "
  type_text "$1" 0.04
  sleep 0.3
}

status_line() {
  local icon="$1"
  local msg="$2"
  local color="${3:-$RESET}"
  echo -e "  ${icon}  ${color}${msg}${RESET}"
}

spinner() {
  local msg="$1"
  local duration="${2:-3}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local end=$((SECONDS + duration))
  while [ $SECONDS -lt $end ]; do
    for frame in "${frames[@]}"; do
      printf "\r  ${CYAN}%s${RESET}  %s" "$frame" "$msg"
      sleep 0.1
    done
  done
  printf "\r  ${GREEN}✔${RESET}  %s\n" "$msg"
}

# ── 메인 데모 시작 ────────────────────────────────────────────
clear

echo
echo -e "${BOLD}${MAGENTA}"
cat << 'EOF'
   ___                  ___                 
  / _ \ _ __  ___ _ _ / __|___ ___ ___ __ 
 | (_) | '_ \/ -_) ' \ (__/ _ \/ _|/ _ \\ \
  \___/| .__/\___|_||_\___\___/\__|\___/_\_\
       |_|   Self-Healing Gateway Demo v1.0
EOF
echo -e "${RESET}"
sleep 1

# ═══════════════════════════════════════════════════════════
# STEP 1: 설치 과정
# ═══════════════════════════════════════════════════════════
print_header "STEP 1 / 6 — 설치 (One-Line Install)"

prompt_line "curl -fsSL https://openclaw.dev/install-healing.sh | bash"
sleep 0.5

echo -e "  ${DIM}Fetching install script from openclaw.dev...${RESET}"
sleep 0.8

spinner "Downloading openclaw-self-healing v1.2.0" 2
spinner "Installing watchdog daemon" 2
spinner "Configuring AI Doctor (claude-opus-4)" 1
spinner "Setting up Discord webhook" 1

echo
status_line "✅" "Installation complete!" "$GREEN"
status_line "📁" "Config: ~/.config/openclaw/healing.yaml" "$DIM"
status_line "🔧" "Daemon: com.openclaw.self-healing (launchd)" "$DIM"
sleep 1.5

# ═══════════════════════════════════════════════════════════
# STEP 2: Gateway 크래시 시뮬레이션
# ═══════════════════════════════════════════════════════════
print_header "STEP 2 / 6 — Gateway 크래시 시뮬레이션"

prompt_line "openclaw gateway status"
sleep 0.3
echo -e "  ${GREEN}● openclaw-gateway — running (pid 38421, uptime 3d 7h)${RESET}"
sleep 1

echo
prompt_line "# [시뮬레이션] Gateway에 잘못된 config 주입..."
sleep 0.5
echo -e "  ${DIM}Injecting malformed config for demo purposes...${RESET}"
sleep 1

echo
echo -e "${RED}${BOLD}  [CRASH] Gateway process terminated unexpectedly${RESET}"
echo -e "${RED}  ✗  Process 38421 exited with code 139 (SIGSEGV)${RESET}"
echo -e "${RED}  ✗  Cause: Invalid token format in device-auth.json${RESET}"
sleep 0.5
echo -e "${DIM}  Timestamp: $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
sleep 1.5

# ═══════════════════════════════════════════════════════════
# STEP 3: Level 0 자동 복구
# ═══════════════════════════════════════════════════════════
print_header "STEP 3 / 6 — Level 0: 즉시 자동 재시작 (0-30초)"

echo -e "  ${YELLOW}⚡ Watchdog detected crash — initiating Level 0 recovery${RESET}"
sleep 0.5

for i in 1 2 3; do
  echo -ne "  ${CYAN}↻${RESET}  Restart attempt ${i}/3..."
  sleep 1.2
  if [ "$i" -lt 3 ]; then
    echo -e " ${RED}FAILED${RESET} (process died within 5s)"
    sleep 0.5
  else
    echo -e " ${GREEN}SUCCESS${RESET}"
  fi
done

sleep 0.5
echo
status_line "✅" "Gateway restarted — uptime: 0:00:08" "$GREEN"
status_line "📊" "Level 0 recovery time: 18 seconds" "$CYAN"
sleep 2

# ═══════════════════════════════════════════════════════════
# STEP 4: 반복 크래시 → Level 1-2
# ═══════════════════════════════════════════════════════════
print_header "STEP 4 / 6 — Level 1-2: 반복 크래시 → doctor --fix"

echo -e "  ${YELLOW}⚠️  Crash loop detected (3 crashes within 10 minutes)${RESET}"
echo -e "  ${YELLOW}⚠️  Escalating to Level 1: Config validation + rollback${RESET}"
sleep 0.8

echo
prompt_line "openclaw doctor --fix --level 1"
sleep 0.3

spinner "Scanning config files for errors" 2
echo -e "  ${RED}  ✗  device-auth.json: invalid token format detected${RESET}"
echo -e "  ${RED}  ✗  healing.yaml: missing 'discord_webhook' field${RESET}"
sleep 0.5

spinner "Rolling back to last known good config" 2
status_line "✅" "Config restored from backup (2026-02-17 09:14:22)" "$GREEN"
sleep 0.5

echo
echo -e "  ${YELLOW}⚠️  Gateway still crashing — escalating to Level 2${RESET}"
sleep 0.5

prompt_line "openclaw doctor --fix --level 2"
sleep 0.3
spinner "Checking port conflicts (8765, 8766)" 1
spinner "Verifying SSL certificates" 1
spinner "Testing network connectivity" 1
status_line "✅" "Level 2 fixes applied — no port conflicts found" "$GREEN"
status_line "📊" "Level 1-2 combined time: 47 seconds" "$CYAN"
sleep 1.5

# ═══════════════════════════════════════════════════════════
# STEP 5: AI Doctor 진단 (Level 3)
# ═══════════════════════════════════════════════════════════
print_header "STEP 5 / 6 — Level 3: AI Doctor 심층 진단"

echo -e "  ${MAGENTA}🤖 Invoking AI Doctor (claude-opus-4) for deep analysis${RESET}"
sleep 0.8

echo
echo -e "  ${DIM}Collecting diagnostic context...${RESET}"
spinner "Reading crash logs (last 500 lines)" 2
spinner "Analyzing heap dump" 2
spinner "Reviewing git history for config changes" 1

echo
echo -e "  ${CYAN}━━━ AI Doctor Report ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo
sleep 0.3
echo -e "  ${BOLD}Root Cause Identified:${RESET}"
sleep 0.3
echo -e "  ${DIM}The device-auth.json token was corrupted during a${RESET}"
echo -e "  ${DIM}concurrent write operation. A race condition between${RESET}"
echo -e "  ${DIM}the token refresh daemon and the config writer caused${RESET}"
echo -e "  ${DIM}partial writes, resulting in invalid JSON structure.${RESET}"
sleep 1

echo
echo -e "  ${BOLD}Recommended Fix:${RESET}"
echo -e "  ${GREEN}  1. Rotate device token via: openclaw devices rotate${RESET}"
echo -e "  ${GREEN}  2. Add file lock to token refresh daemon (patch ready)${RESET}"
echo -e "  ${GREEN}  3. Enable atomic writes in config handler${RESET}"
sleep 0.5

echo
spinner "Applying AI-recommended patches" 3
spinner "Rotating device authentication token" 2
status_line "✅" "AI Doctor fix applied successfully" "$GREEN"
status_line "📊" "Level 3 diagnosis time: 2m 14s" "$CYAN"
sleep 1.5

# ═══════════════════════════════════════════════════════════
# STEP 6: Discord 알림 (Level 4)
# ═══════════════════════════════════════════════════════════
print_header "STEP 6 / 6 — Level 4: Discord 알림 + 인간 에스컬레이션"

echo -e "  ${YELLOW}🔔 Persistent issue detected — triggering Level 4 alert${RESET}"
sleep 0.5

echo
echo -e "  ${DIM}Sending notification to Discord #jarvis-system...${RESET}"
sleep 0.8

echo -e "  ${CYAN}┌─────────────────────────────────────────────────┐${RESET}"
echo -e "  ${CYAN}│${RESET} ${BOLD}🚨 OpenClaw Self-Healing — Level 4 Alert${RESET}         ${CYAN}│${RESET}"
echo -e "  ${CYAN}│${RESET}                                                 ${CYAN}│${RESET}"
echo -e "  ${CYAN}│${RESET}  ${RED}Status:${RESET}  Gateway 불안정 (5회 크래시 / 1시간)      ${CYAN}│${RESET}"
echo -e "  ${CYAN}│${RESET}  ${YELLOW}Level:${RESET}   Level 4 — 인간 개입 필요               ${CYAN}│${RESET}"
echo -e "  ${CYAN}│${RESET}  ${GREEN}AI Fix:${RESET}  토큰 교체 + 파일 락 패치 적용됨         ${CYAN}│${RESET}"
echo -e "  ${CYAN}│${RESET}  📎 Logs: /var/log/openclaw/crash-20260218.log  ${CYAN}│${RESET}"
echo -e "  ${CYAN}└─────────────────────────────────────────────────┘${RESET}"
sleep 0.5
echo -e "  ${GREEN}✅ Discord notification sent to @정우님${RESET}"
sleep 1

# ── 최종 요약 ────────────────────────────────────────────────
print_separator
echo
echo -e "${BOLD}${GREEN}  🎉 Self-Healing Demo Complete!${RESET}"
echo
echo -e "  ${BOLD}Recovery Timeline:${RESET}"
echo -e "  ${GREEN}  ⏱  Level 0 (Auto-restart):        18s${RESET}"
echo -e "  ${GREEN}  ⏱  Level 1-2 (Config fix):        47s${RESET}"
echo -e "  ${GREEN}  ⏱  Level 3 (AI Doctor):         2m 14s${RESET}"
echo -e "  ${GREEN}  ⏱  Level 4 (Human escalation):    5s${RESET}"
echo -e "  ${CYAN}  ─────────────────────────────────────${RESET}"
echo -e "  ${BOLD}${CYAN}  Total:                         ~4 minutes${RESET}"
echo
echo -e "  ${DIM}vs. Traditional watchdog: ∞ (manual intervention required)${RESET}"
echo
print_separator
echo -e "  ${BOLD}Learn more:${RESET} https://github.com/ramsbaby/openclaw-self-healing"
print_separator
echo
