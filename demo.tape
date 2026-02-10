# VHS Demo Script for OpenClaw Self-Healing System v2.1
# https://github.com/charmbracelet/vhs

Output demo.gif

Set Shell "bash"
Set FontSize 15
Set Width 1000
Set Height 500
Set Theme "Dracula"
Set Padding 15
Set TypingSpeed 40ms

# Title
Type "echo '🦞 OpenClaw Self-Healing v2.1 — Cross-Platform Demo'"
Enter
Sleep 1.5s

# Show platform support
Type "echo ''"
Enter
Type "echo '📦 Supported: macOS (LaunchAgent) + Linux (systemd)'"
Enter
Sleep 1s

# Step 1: Install
Type "echo ''"
Enter
Type "echo '━━━ Step 1: One-Click Install ━━━'"
Enter
Sleep 500ms
Type "echo '$ curl -sSL .../install.sh | bash  # auto-detects OS'"
Enter
Sleep 1.5s

# Step 2: Show what's running
Type "echo ''"
Enter
Type "echo '━━━ Step 2: Health Check Running ━━━'"
Enter
Sleep 500ms
Type "tail -3 ~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log 2>/dev/null || echo '[2026-02-10 09:00:01] ✅ Gateway healthy'"
Enter
Sleep 1.5s

# Step 3: Simulate failure
Type "echo ''"
Enter
Type "echo '━━━ Step 3: 💥 Gateway Crashes! ━━━'"
Enter
Sleep 500ms
Type "echo '[2026-02-10 09:05:01] ⚠️ HTTP check failed: HTTP 000'"
Enter
Sleep 500ms
Type "echo '[2026-02-10 09:05:01] Retry 1/3...'"
Enter
Sleep 300ms
Type "echo '[2026-02-10 09:05:32] Restarting OpenClaw Gateway...'"
Enter
Sleep 300ms
Type "echo '[2026-02-10 09:06:02] ✅ Recovery successful on retry 1'"
Enter
Sleep 1.5s

# Step 4: Level 3
Type "echo ''"
Enter
Type "echo '━━━ Step 4: 🧠 If restart fails → Claude Doctor ━━━'"
Enter
Sleep 500ms
Type "echo '[2026-02-10 09:10:01] 🚨 Escalating to Level 3 (Claude Emergency Recovery)'"
Enter
Sleep 300ms
Type "echo '[2026-02-10 09:10:05] Claude: Analyzing logs... config issue detected'"
Enter
Sleep 300ms
Type "echo '[2026-02-10 09:10:15] Claude: Fixed gateway.json → restarting...'"
Enter
Sleep 300ms
Type "echo '[2026-02-10 09:10:25] ✅ Claude successfully recovered the gateway!'"
Enter
Sleep 1.5s

# Step 5: Discord alert
Type "echo ''"
Enter
Type "echo '━━━ Step 5: 📱 Discord Notification ━━━'"
Enter
Sleep 500ms
Type "echo '✅ Level 3 Emergency Recovery 성공! (25초)'"
Enter
Sleep 1.5s

# Summary
Type "echo ''"
Enter
Type "echo '🦞 AI heals AI. Sleep well.'"
Enter
Sleep 2s
