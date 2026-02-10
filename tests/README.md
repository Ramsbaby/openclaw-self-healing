# OpenClaw Self-Healing Test Suite

Automated tests using [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

## Prerequisites

Install BATS:

```bash
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt install bats

# From source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

Install additional BATS libraries (optional but recommended):

```bash
# bats-support: output formatting helpers
# bats-assert: assertion helpers
# bats-file: file system helpers

git clone https://github.com/bats-core/bats-support tests/test_helper/bats-support
git clone https://github.com/bats-core/bats-assert tests/test_helper/bats-assert
git clone https://github.com/bats-core/bats-file tests/test_helper/bats-file
```

## Running Tests

### Run all tests

```bash
bats tests/*.bats
```

### Run specific test file

```bash
bats tests/healthcheck.bats
bats tests/emergency-recovery.bats
bats tests/monitor.bats
bats tests/install.bats
```

### Run with verbose output

```bash
bats -t tests/healthcheck.bats
```

### Run in parallel (faster)

```bash
bats -j 4 tests/*.bats
```

## Test Coverage

### healthcheck.bats
- ✅ HTTP check succeeds on 200 response
- ✅ HTTP check fails on 500 response
- ✅ Lock file prevents concurrent execution
- ✅ Retries configured number of times
- ✅ Metrics file is created and valid JSON
- ✅ Uses custom GATEWAY_URL from environment
- ✅ Skips Discord notification when webhook not set

### emergency-recovery.bats
- ⚠️ Lock file prevents concurrent recovery (requires full script)
- ⚠️ tmux session name includes timestamp (integration test)
- ⚠️ tmux session is cleaned up on exit (integration test)
- ⚠️ Recovery respects timeout setting (requires Claude CLI mock)
- ⚠️ Recovery metrics are recorded (integration test)
- ✅ Validates required commands exist
- ✅ Handles corrupted metrics JSON gracefully
- ✅ Handles missing environment variables
- ✅ Handles spaces in file paths

### monitor.bats
- ✅ Detects MANUAL INTERVENTION REQUIRED pattern
- ✅ Ignores logs without failure pattern
- ⚠️ Alert tracking file prevents duplicate alerts (requires script execution)
- ⚠️ Alert tracking respects time window (requires script execution)
- ✅ Extracts relevant log lines for alert
- ⚠️ Handles empty log directory (requires script)
- ⚠️ Monitor detects failure and sends alert (integration test)

### install.bats
- ⚠️ All tests require install script execution or enhancement
- ✅ Creates necessary directories
- ✅ Sets correct file permissions

## Test Status

| Category | Unit Tests | Integration Tests | Total |
|----------|-----------|-------------------|-------|
| Health Check | 7 passing | 0 | 7 |
| Emergency Recovery | 4 passing | 6 skipped | 10 |
| Monitor | 3 passing | 5 skipped | 8 |
| Install | 2 passing | 8 skipped | 10 |
| **Total** | **16 passing** | **19 skipped** | **35** |

**Current Coverage:** ~46% (16/35 tests active)

**Target Coverage:** 80%+ (28+/35 tests active)

## Skipped Tests

Tests marked with `skip` require one of:
1. **Full integration environment** (tmux, Claude CLI, OpenClaw Gateway running)
2. **Network mocking** (for Discord/Telegram webhooks)
3. **Platform-specific features** (macOS LaunchAgent, Linux systemd)
4. **Script enhancements** (e.g., `--verify`, `--rollback` flags not yet implemented)

To enable skipped tests:
1. Set up full test environment with running Gateway
2. Implement missing features (rollback, verify)
3. Use network mocking libraries

## Writing New Tests

### Basic test structure

```bash
@test "Description of what's being tested" {
  # Setup
  export VAR="value"

  # Execute
  run command_to_test

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"expected string"* ]]
}
```

### Using mocks

```bash
setup() {
  export TEST_DIR="$(mktemp -d)"
  export PATH="$TEST_DIR/mocks:$PATH"

  # Create mock command
  cat > "$TEST_DIR/mocks/curl" << 'EOF'
#!/bin/bash
echo "200"
exit 0
EOF
  chmod +x "$TEST_DIR/mocks/curl"
}

teardown() {
  rm -rf "$TEST_DIR"
}
```

### Testing edge cases

```bash
@test "Handles missing file gracefully" {
  run command_that_reads_file /nonexistent/file
  [ "$status" -ne 0 ]
  [[ "$output" == *"file not found"* ]]
}
```

## CI Integration

Tests run automatically on GitHub Actions via ShellCheck workflow.

To add BATS tests to CI:

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  bats:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install BATS
        run: |
          sudo apt-get update
          sudo apt-get install -y bats

      - name: Run tests
        run: bats tests/*.bats
```

## Troubleshooting

### "bats: command not found"
Install BATS (see Prerequisites)

### "Tests hang indefinitely"
- Check for infinite loops in scripts
- Add `timeout` wrapper: `timeout 30s bats tests/file.bats`

### "Permission denied" errors
- Ensure test scripts have execute permissions
- Check mock commands are executable

### "tmux: sessions would be nested"
- Tests should kill lingering tmux sessions in `teardown()`
- Use unique session names with timestamps/UUIDs

## Future Improvements

1. **Increase coverage to 80%+**
   - Implement missing script features (rollback, verify)
   - Add network mocking for webhook tests
   - Create full integration test environment

2. **Performance tests**
   - Large log file handling
   - Concurrent execution stress tests
   - Memory leak detection

3. **Security tests**
   - Verify file permissions (600 for logs)
   - Test secret handling (no leaks in logs)
   - Validate input sanitization

4. **Mutation testing**
   - Use mutation testing to find untested code paths
   - Improve assertion quality

## Contributing

When adding new features:
1. Write tests first (TDD)
2. Run `bats tests/*.bats` before committing
3. Update this README with new test descriptions
4. Ensure CI passes

## References

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [BATS Tutorial](https://github.com/bats-core/bats-core#usage)
- [Testing Best Practices](https://google.github.io/styleguide/shellguide.html#s6-testing)
