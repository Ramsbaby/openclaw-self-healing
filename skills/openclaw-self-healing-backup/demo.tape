# VHS Demo Script for OpenClaw Self-Healing System
# https://github.com/charmbracelet/vhs

Output demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 1200
Set Height 600
Set Theme "Dracula"
Set Padding 20

# Title
Type "# 🦞 OpenClaw Self-Healing System Demo"
Enter
Sleep 1s

Type "# Level 1-4 Autonomous Recovery"
Enter
Sleep 1s

Enter
Type "# Step 1: Check Gateway Status"
Enter
Sleep 500ms

Type "openclaw status"
Enter
Sleep 2s

Enter
Type "# Step 2: Simulate Gateway Crash"
Enter
Sleep 500ms

Type "echo '⚠️ Simulating Gateway failure...'"
Enter
Sleep 1s

Type "pkill -f 'openclaw gateway' 2>/dev/null || echo 'Gateway stopped'"
Enter
Sleep 1s

Enter
Type "# Step 3: Health Check Detects Failure"
Enter
Sleep 500ms

Type "~/openclaw/scripts/gateway-healthcheck.sh"
Enter
Sleep 3s

Enter
Type "# Step 4: Level 3 Claude Doctor (if needed)"
Enter
Sleep 500ms

Type "echo '🧠 Claude Code would diagnose and fix automatically...'"
Enter
Sleep 1s

Type "echo '📋 All actions logged to ~/openclaw/memory/emergency-recovery-*.log'"
Enter
Sleep 1s

Enter
Type "# Step 5: Verify Recovery"
Enter
Sleep 500ms

Type "openclaw status"
Enter
Sleep 2s

Enter
Type "# ✅ Self-Healing Complete!"
Enter
Type "echo '🦞 AI heals AI - The system that fixes itself.'"
Enter
Sleep 2s
