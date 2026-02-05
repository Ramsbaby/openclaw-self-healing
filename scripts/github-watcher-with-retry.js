#!/usr/bin/env node
/**
 * GitHub Watcher with Auto-Retry (Level 1 Self-Improvement)
 *
 * Wraps the github-watcher shell script with automatic retry
 * Closes the loop: GitHub API failure → Retry → Success
 */

const { executeWithNotifications } = require('../lib/auto-retry');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  SCRIPT_PATH: path.join(process.env.HOME, 'openclaw/skills/github-watcher/check.sh'),

  // Retry settings
  MAX_RETRIES: 3,
  BACKOFF: 'exponential',

  // Discord
  DISCORD_WEBHOOK: JSON.parse(
    fs.readFileSync(path.join(process.env.HOME, '.openclaw/monitoring.json'), 'utf8')
  ).webhook.url
};

// ============================================================================
// Execute Shell Script
// ============================================================================

async function checkGitHub() {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();

    exec(CONFIG.SCRIPT_PATH, {
      timeout: 15000,  // 15초 타임아웃
      maxBuffer: 10 * 1024 * 1024  // 10MB
    }, (error, stdout, stderr) => {
      const duration = Date.now() - startTime;

      if (error) {
        // Error classification for retry decision
        if (error.killed || error.signal === 'SIGTERM') {
          error.code = 'ETIMEDOUT';
        }
        error.duration = duration;
        reject(error);
      } else {
        resolve({
          output: stdout,
          stderr: stderr,
          duration: duration
        });
      }
    });
  });
}

// ============================================================================
// Main
// ============================================================================

async function main() {
  console.log('🐙 GitHub 감시 (with Auto-Retry)\n');

  try {
    // Execute with auto-retry
    const result = await executeWithNotifications(
      checkGitHub,
      {
        maxRetries: CONFIG.MAX_RETRIES,
        backoff: CONFIG.BACKOFF,
        discordWebhook: CONFIG.DISCORD_WEBHOOK,
        taskName: 'GitHub 감시',
        context: {
          cron: 'GitHub 감시',
          schedule: '50 16 * * 1-5',
          task: 'check github notifications'
        }
      }
    );

    // Success!
    console.log('\n✅ Success');
    console.log(`   Attempts: ${result.attempts}`);
    console.log(`   Duration: ${result.totalDuration}ms`);
    console.log(`   Script execution: ${result.result.duration}ms`);

    // Output the script result
    console.log('\n' + result.result.output);

    if (result.result.stderr) {
      console.error('\nStderr:', result.result.stderr);
    }

    // Exit with success
    process.exit(0);

  } catch (error) {
    // Final failure after all retries
    console.error('\n❌ Failed after all retries');
    console.error(`   Error: ${error.message}`);

    if (error.stderr) {
      console.error(`   Stderr: ${error.stderr}`);
    }

    // Exit with error
    process.exit(1);
  }
}

// ============================================================================
// Run
// ============================================================================

if (require.main === module) {
  main();
}

module.exports = { checkGitHub, CONFIG };
