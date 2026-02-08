# Contributing to OpenClaw Self-Healing System

> **Thank you for considering contributing!** Every improvement, bug fix, and documentation update makes this project better for the entire OpenClaw community.

---

## 🌟 Ways to Contribute

### 1. **Bug Reports** 🐛
Found something broken? [Open an issue](https://github.com/ramsbaby/openclaw-self-healing/issues/new?template=bug_report.md).

**Please include:**
- macOS version (`sw_vers`)
- OpenClaw version (`openclaw version`)
- Self-Healing script versions (`head -5 ~/openclaw/scripts/*.sh`)
- Relevant logs (last 50 lines of `healthcheck-*.log` or `emergency-recovery-*.log`)
- Steps to reproduce

### 2. **Feature Requests** 💡
Have an idea? [Open an issue](https://github.com/ramsbaby/openclaw-self-healing/issues/new?template=feature_request.md).

**We're especially interested in:**
- Linux (systemd) support
- Alternative LLM integrations (GPT-4, Gemini, etc.)
- Prometheus/Grafana metrics
- Additional notification channels (Slack, Telegram, etc.)

### 3. **Pull Requests** 🔧
Code contributions are welcome!

**Good first PRs:**
- Documentation improvements
- Bug fixes with test cases
- New notification channels
- systemd equivalent for Linux

### 4. **Documentation** 📚
Help others by improving docs:
- Fix typos or unclear sections
- Add examples or tutorials
- Translate documentation
- Write blog posts/guides

### 5. **Testing & Validation** 🧪
Help verify the system works in different environments:
- Test on different macOS versions
- Test with different OpenClaw configurations
- Test edge cases (network failures, disk full, etc.)

---

## 🚀 Development Setup

### Prerequisites

```bash
# Clone the repo
git clone https://github.com/ramsbaby/openclaw-self-healing.git
cd openclaw-self-healing

# Install dependencies
brew install tmux shellcheck
npm install -g @anthropic-ai/claude-code

# Copy environment template
cp .env.example ~/.openclaw/.env
```

### Code Style

**Bash scripts:**
- Use `shellcheck` for linting: `shellcheck scripts/*.sh`
- 2-space indentation
- Meaningful variable names (avoid `$a`, `$b`, etc.)
- Add comments for non-obvious logic
- Use functions for reusable code

**Example:**
```bash
#!/bin/bash

# Good: Clear function name, descriptive variables
check_gateway_health() {
  local gateway_url="$1"
  local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$gateway_url")
  
  if [ "$http_code" = "200" ]; then
    return 0
  else
    log "Gateway unhealthy: HTTP $http_code"
    return 1
  fi
}

# Bad: Cryptic, hard to understand
chk() {
  local u="$1"
  local c=$(curl -s -o /dev/null -w "%{http_code}" "$u")
  [ "$c" = "200" ] && return 0 || return 1
}
```

---

## 🔀 Pull Request Process

### 1. Fork & Branch

```bash
# Fork the repo on GitHub, then:
git clone https://github.com/YOUR_USERNAME/openclaw-self-healing.git
cd openclaw-self-healing

# Create a feature branch
git checkout -b feature/your-feature-name
```

### 2. Make Changes

```bash
# Edit files
nano scripts/gateway-healthcheck.sh

# Run shellcheck
shellcheck scripts/*.sh

# Test manually
bash scripts/gateway-healthcheck.sh
```

### 3. Test Thoroughly

**Required tests before submitting PR:**

- [ ] **Level 1 (Watchdog):** Kill Gateway, verify auto-restart
- [ ] **Level 2 (Health Check):** Simulate failure, verify retries
- [ ] **Level 3 (Claude Recovery):** Inject config error, verify Claude diagnosis
- [ ] **Level 4 (Discord Alert):** Simulate Level 3 failure, verify notification

**Test checklist:**
```bash
# 1. Kill Gateway
kill -9 $(pgrep -f openclaw-gateway)
sleep 180
curl http://localhost:18789/
# Expected: HTTP 200

# 2. Stop Gateway manually
openclaw gateway stop
tail -f ~/openclaw/memory/healthcheck-$(date +%Y-%m-%d).log
# Expected: Restart attempts

# 3. Break config (backup first!)
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak
# (edit to break Gateway)
# Wait 8 minutes, check Level 3 logs

# 4. Simulate Level 3 failure
# (see TROUBLESHOOTING.md)
bash ~/openclaw/scripts/emergency-recovery-monitor.sh
# Expected: Discord alert or console output
```

### 4. Commit & Push

```bash
# Stage changes
git add scripts/gateway-healthcheck.sh

# Commit with descriptive message
git commit -m "feat: Add configurable retry delay for Health Check

- Add HEALTH_CHECK_RETRY_DELAY environment variable
- Default 30s, configurable via .env
- Update documentation with new variable"

# Push to your fork
git push origin feature/your-feature-name
```

### 5. Open Pull Request

Go to GitHub and click "New Pull Request".

**PR Template:**

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring

## Testing
- [ ] Tested Level 1 (Watchdog)
- [ ] Tested Level 2 (Health Check)
- [ ] Tested Level 3 (Claude Recovery)
- [ ] Tested Level 4 (Discord Alert)
- [ ] Ran shellcheck
- [ ] Tested on macOS X.X

## Screenshots/Logs (if applicable)
Paste relevant logs or screenshots here.

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-reviewed code
- [ ] Commented hard-to-understand areas
- [ ] Updated documentation
- [ ] No breaking changes (or documented)
```

### 6. Code Review

Maintainers will review your PR. Be responsive to feedback:
- Answer questions
- Make requested changes
- Re-test if needed

**Review timeline:**
- Initial review: 1-3 days
- Revisions: As needed
- Merge: When approved by 1+ maintainer

---

## 📐 Coding Standards

### Bash Best Practices

1. **Always quote variables:**
   ```bash
   # Good
   if [ "$http_code" = "200" ]; then
   
   # Bad
   if [ $http_code = "200" ]; then
   ```

2. **Use meaningful names:**
   ```bash
   # Good
   RECOVERY_TIMEOUT=1800
   
   # Bad
   T=1800
   ```

3. **Check exit codes:**
   ```bash
   # Good
   if curl -X POST "$DISCORD_WEBHOOK" ... ; then
     log "Success"
   else
     log "Failed"
   fi
   
   # Bad
   curl -X POST "$DISCORD_WEBHOOK" ...
   ```

4. **Use functions:**
   ```bash
   # Good
   send_discord_notification() {
     local message="$1"
     # ... implementation
   }
   
   # Bad
   # Duplicate code multiple times
   ```

5. **Set exit trap for cleanup:**
   ```bash
   # Good
   trap "rm -f $LOCKFILE" EXIT
   
   # Bad
   # Forget to cleanup, leave stale locks
   ```

### Documentation Standards

1. **Update README.md** if adding/changing features
2. **Update QUICKSTART.md** if changing installation
3. **Update TROUBLESHOOTING.md** if fixing bugs
4. **Add inline comments** for complex logic

---

## 🧪 Testing Requirements

### Unit Tests (Manual)

```bash
# Test individual functions
bash -c '
source scripts/gateway-healthcheck.sh
check_http
echo "Exit code: $?"
'
```

### Integration Tests

```bash
# Test full workflow
# 1. Stop Gateway
# 2. Wait for Health Check trigger
# 3. Verify Level 2 recovery
# 4. If Level 3 needed, verify Claude session
# 5. Verify Discord notification
```

### Edge Case Tests

- **Network failure:** Disconnect wifi, verify graceful degradation
- **Disk full:** Fill disk, verify logs don't crash system
- **Claude quota exhausted:** Verify Level 3 → Level 4 escalation
- **Discord webhook invalid:** Verify fallback to console output

---

## 🏷️ Commit Message Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format
<type>(<scope>): <subject>

<body>

# Types
feat:     New feature
fix:      Bug fix
docs:     Documentation only
style:    Formatting, missing semicolons, etc.
refactor: Code restructuring without changing behavior
test:     Adding tests
chore:    Maintenance tasks

# Examples
feat(health-check): Add configurable retry delay
fix(emergency-recovery): Handle Claude quota exceeded
docs(quickstart): Add macOS 15 compatibility note
refactor(discord): Extract notification function
```

---

## 🚧 WIP (Work in Progress) Contributions

Have an idea but not finished? That's OK!

1. Open a **Draft PR** on GitHub
2. Mark it as **WIP** in the title
3. Ask for early feedback
4. Convert to regular PR when ready

---

## 📜 Code of Conduct

### Be Respectful

- Constructive criticism, not personal attacks
- Assume good intent
- Help others learn

### Be Patient

- Maintainers are volunteers
- Reviews take time
- Not all PRs will be merged (but all are appreciated)

### Be Collaborative

- Discuss before major changes
- Share knowledge
- Credit others' work

---

## 🎁 Recognition

Contributors are recognized in:
- **README.md** — "Contributors" section
- **CHANGELOG.md** — Release notes
- **GitHub Contributors** — Automatic attribution

---

## 📞 Questions?

- **GitHub Discussions:** [github.com/ramsbaby/openclaw-self-healing/discussions](https://github.com/ramsbaby/openclaw-self-healing/discussions)
- **OpenClaw Discord:** [discord.com/invite/clawd](https://discord.com/invite/clawd) (mention @ramsbaby)
- **Email:** (if urgent, check GitHub profile)

---

<p align="center">
  <strong>Thank you for making OpenClaw Self-Healing better! 🦞</strong>
</p>
