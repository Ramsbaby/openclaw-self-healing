#!/usr/bin/env node
/**
 * TQQQ Monitor with Auto-Retry (Level 1 Self-Improvement)
 *
 * Wraps the Python yahoo-finance script with automatic retry
 * Closes the loop: API failure → Retry → Success
 */

const { executeWithNotifications } = require('../lib/auto-retry');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  PYTHON_SCRIPT: path.join(process.env.HOME, 'openclaw/skills/yahoo-finance/yf'),
  SYMBOL: 'TQQQ',

  // Retry settings
  MAX_RETRIES: 3,
  BACKOFF: 'exponential',

  // Discord
  DISCORD_WEBHOOK: JSON.parse(
    fs.readFileSync(path.join(process.env.HOME, '.openclaw/monitoring.json'), 'utf8')
  ).webhook.url,

  // TQQQ position (from MEMORY.md)
  POSITION: {
    avgPrice: 50.79,
    shares: 137,
    totalInvested: 10096898  // ₩10,096,898
  },

  // Strategy lines
  STRATEGY: {
    stopLoss: 47.00,      // -7.5%
    buyMore: 49.26,       // -3%
    takeProfit: 52.31     // +3%
  }
};

// ============================================================================
// Execute Python Script
// ============================================================================

async function fetchTQQQ() {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();

    exec(`${CONFIG.PYTHON_SCRIPT} ${CONFIG.SYMBOL}`, {
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
  console.log('📊 TQQQ 15분 모니터링 (with Auto-Retry)\n');

  try {
    // Execute with auto-retry
    const result = await executeWithNotifications(
      fetchTQQQ,
      {
        maxRetries: CONFIG.MAX_RETRIES,
        backoff: CONFIG.BACKOFF,
        discordWebhook: CONFIG.DISCORD_WEBHOOK,
        taskName: 'TQQQ 15분 모니터링',
        context: {
          cron: 'TQQQ 15분 모니터링',
          schedule: '*/15 * * * *',
          symbol: CONFIG.SYMBOL
        }
      }
    );

    // Success!
    console.log('\n✅ Success');
    console.log(`   Attempts: ${result.attempts}`);
    console.log(`   Duration: ${result.totalDuration}ms`);
    console.log(`   Script execution: ${result.result.duration}ms`);

    // Output the Python script result
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

module.exports = { fetchTQQQ, CONFIG };
