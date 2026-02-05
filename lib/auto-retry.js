#!/usr/bin/env node
/**
 * Auto-Retry System (Level 1 Self-Improvement)
 *
 * Purpose: Automatically retry failed operations with intelligent backoff
 * Closes the loop: Failure → Analyze → Retry → Success (automatic!)
 *
 * Features:
 * - Verifiable outcomes (exit code, HTTP status, errors)
 * - Exponential/linear backoff
 * - Error analysis and classification
 * - Automatic logging
 * - Discord notifications (optional)
 */

const fs = require('fs');
const path = require('path');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  // Default retry settings
  DEFAULT_MAX_RETRIES: 3,
  DEFAULT_BACKOFF: 'exponential',
  DEFAULT_BASE_DELAY: 1000, // 1초

  // Retry decision
  RETRYABLE_ERROR_CODES: [
    'ETIMEDOUT',
    'ECONNRESET',
    'ENOTFOUND',
    'EAI_AGAIN',
    'ECONNREFUSED'
  ],

  RETRYABLE_HTTP_STATUS: [408, 429, 500, 502, 503, 504],

  // Logging
  LOG_DIR: path.join(process.env.HOME, 'openclaw', 'logs'),
  LOG_FILE: 'auto-retry.jsonl',
};

// ============================================================================
// Core: Auto-Retry Engine
// ============================================================================

class AutoRetry {
  constructor(options = {}) {
    this.maxRetries = options.maxRetries || CONFIG.DEFAULT_MAX_RETRIES;
    this.backoff = options.backoff || CONFIG.DEFAULT_BACKOFF;
    this.baseDelay = options.baseDelay || CONFIG.DEFAULT_BASE_DELAY;
    this.onRetry = options.onRetry || null;
    this.onSuccess = options.onSuccess || null;
    this.onFinalFailure = options.onFinalFailure || null;
  }

  /**
   * Execute function with automatic retry
   */
  async execute(fn, context = {}) {
    const startTime = Date.now();
    const attempts = [];

    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      const attemptStart = Date.now();

      try {
        // Execute function
        const result = await fn();

        // Success!
        const duration = Date.now() - attemptStart;
        const totalDuration = Date.now() - startTime;

        attempts.push({
          attempt,
          success: true,
          duration
        });

        // Log success
        await this.logSuccess({
          context,
          attempts,
          totalDuration,
          result
        });

        // Callback
        if (this.onSuccess) {
          await this.onSuccess(attempt, result, attempts);
        }

        return {
          success: true,
          result,
          attempts: attempt,
          totalDuration
        };

      } catch (error) {
        // Failure
        const duration = Date.now() - attemptStart;
        const analysis = this.analyzeError(error);

        attempts.push({
          attempt,
          success: false,
          duration,
          error: analysis
        });

        // Last attempt?
        if (attempt === this.maxRetries) {
          await this.logFailure({
            context,
            attempts,
            totalDuration: Date.now() - startTime,
            finalError: analysis
          });

          if (this.onFinalFailure) {
            await this.onFinalFailure(attempts, analysis);
          }

          throw error;
        }

        // Retryable?
        if (!analysis.retryable) {
          await this.logFailure({
            context,
            attempts,
            totalDuration: Date.now() - startTime,
            finalError: analysis,
            reason: 'Non-retryable error'
          });

          throw error;
        }

        // Calculate backoff delay
        const delay = this.calculateBackoff(attempt);

        // Callback
        if (this.onRetry) {
          await this.onRetry(attempt, error, analysis, delay);
        }

        // Wait before retry
        await this.sleep(delay);
      }
    }
  }

  /**
   * Analyze error to determine if retryable
   */
  analyzeError(error) {
    const analysis = {
      type: error.code || error.name || 'Unknown',
      message: error.message,
      statusCode: error.statusCode || error.status,
      retryable: false,
      category: 'unknown',
      suggestedFix: 'Unknown error'
    };

    // Network errors
    if (CONFIG.RETRYABLE_ERROR_CODES.includes(error.code)) {
      analysis.retryable = true;
      analysis.category = 'network';
      analysis.suggestedFix = this.suggestNetworkFix(error.code);
    }

    // HTTP errors
    if (CONFIG.RETRYABLE_HTTP_STATUS.includes(error.statusCode)) {
      analysis.retryable = true;
      analysis.category = 'http';
      analysis.suggestedFix = this.suggestHTTPFix(error.statusCode);
    }

    // Timeout
    if (error.message && error.message.includes('timeout')) {
      analysis.retryable = true;
      analysis.category = 'timeout';
      analysis.suggestedFix = 'Increase timeout or check network';
    }

    return analysis;
  }

  suggestNetworkFix(code) {
    const fixes = {
      'ETIMEDOUT': 'Network timeout - check connection or increase timeout',
      'ECONNRESET': 'Connection reset - server may be restarting',
      'ENOTFOUND': 'DNS lookup failed - check hostname',
      'EAI_AGAIN': 'DNS temporary failure - retry should work',
      'ECONNREFUSED': 'Connection refused - check if service is running'
    };
    return fixes[code] || 'Network error';
  }

  suggestHTTPFix(status) {
    const fixes = {
      408: 'Request timeout - increase timeout',
      429: 'Rate limit exceeded - increase backoff delay',
      500: 'Internal server error - temporary, retry should work',
      502: 'Bad gateway - upstream server issue',
      503: 'Service unavailable - server overloaded',
      504: 'Gateway timeout - upstream server timeout'
    };
    return fixes[status] || 'HTTP error';
  }

  /**
   * Calculate backoff delay
   */
  calculateBackoff(attempt) {
    if (this.backoff === 'exponential') {
      // 1s, 2s, 4s, 8s, 16s...
      return this.baseDelay * Math.pow(2, attempt - 1);
    } else if (this.backoff === 'linear') {
      // 1s, 2s, 3s, 4s...
      return this.baseDelay * attempt;
    } else {
      // Fixed delay
      return this.baseDelay;
    }
  }

  /**
   * Sleep utility
   */
  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Log success
   */
  async logSuccess(data) {
    await this.writeLog({
      timestamp: new Date().toISOString(),
      type: 'success',
      ...data
    });
  }

  /**
   * Log failure
   */
  async logFailure(data) {
    await this.writeLog({
      timestamp: new Date().toISOString(),
      type: 'failure',
      ...data
    });
  }

  /**
   * Write log to file (JSONL format)
   */
  async writeLog(entry) {
    try {
      // Ensure log directory exists
      if (!fs.existsSync(CONFIG.LOG_DIR)) {
        fs.mkdirSync(CONFIG.LOG_DIR, { recursive: true });
      }

      const logFile = path.join(CONFIG.LOG_DIR, CONFIG.LOG_FILE);
      const line = JSON.stringify(entry) + '\n';

      fs.appendFileSync(logFile, line);
    } catch (e) {
      console.error('Failed to write log:', e.message);
    }
  }
}

// ============================================================================
// Convenience Functions
// ============================================================================

/**
 * Simple wrapper for common use cases
 */
async function executeWithRetry(fn, options = {}) {
  const retry = new AutoRetry(options);
  return await retry.execute(fn, options.context || {});
}

/**
 * Retry with Discord notifications
 */
async function executeWithNotifications(fn, options = {}) {
  const { discordWebhook, taskName } = options;

  return await executeWithRetry(fn, {
    ...options,
    onRetry: async (attempt, error, analysis, delay) => {
      if (discordWebhook) {
        await sendDiscordNotification(discordWebhook, {
          title: '🔄 재시도 중',
          description: `**${taskName}** (시도 ${attempt}/${options.maxRetries || 3})`,
          color: 0xFFA500,
          fields: [
            { name: '에러', value: error.message, inline: false },
            { name: '카테고리', value: analysis.category, inline: true },
            { name: '다음 시도', value: `${delay}ms 후`, inline: true }
          ]
        });
      }

      // Console log
      console.log(`⚠️  Retry ${attempt}: ${error.message} (waiting ${delay}ms)`);
    },
    onSuccess: async (attempt, result) => {
      if (discordWebhook && attempt > 1) {
        await sendDiscordNotification(discordWebhook, {
          title: '✅ 재시도 성공',
          description: `**${taskName}** (${attempt}번째 시도에서 성공)`,
          color: 0x00FF00
        });
      }

      console.log(`✅ Success after ${attempt} attempt(s)`);
    },
    onFinalFailure: async (attempts, analysis) => {
      if (discordWebhook) {
        await sendDiscordNotification(discordWebhook, {
          title: '❌ 최종 실패',
          description: `**${taskName}** (${attempts.length}회 시도 후 실패)`,
          color: 0xFF0000,
          fields: [
            { name: '제안', value: analysis.suggestedFix, inline: false }
          ]
        });
      }

      console.error(`❌ Failed after ${attempts.length} attempts`);
    }
  });
}

/**
 * Send Discord notification
 */
async function sendDiscordNotification(webhookUrl, embed) {
  const https = require('https');
  const url = new URL(webhookUrl);

  const message = {
    embeds: [{
      title: embed.title,
      description: embed.description,
      color: embed.color,
      fields: embed.fields || [],
      footer: { text: 'Auto-Retry System' },
      timestamp: new Date().toISOString()
    }]
  };

  return new Promise((resolve, reject) => {
    const data = JSON.stringify(message);

    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = https.request(options, (res) => {
      if (res.statusCode === 204) {
        resolve();
      } else {
        reject(new Error(`Discord returned ${res.statusCode}`));
      }
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// ============================================================================
// Exports
// ============================================================================

module.exports = {
  AutoRetry,
  executeWithRetry,
  executeWithNotifications
};

// ============================================================================
// CLI Usage (for testing)
// ============================================================================

if (require.main === module) {
  const testFn = async () => {
    // Simulate random failure
    if (Math.random() < 0.7) {
      const error = new Error('Simulated network timeout');
      error.code = 'ETIMEDOUT';
      throw error;
    }
    return { data: 'Success!' };
  };

  console.log('🧪 Testing Auto-Retry System...\n');

  executeWithRetry(testFn, {
    maxRetries: 5,
    backoff: 'exponential',
    context: { task: 'test' },
    onRetry: (attempt, error, analysis, delay) => {
      console.log(`  Retry ${attempt}: ${error.message} (waiting ${delay}ms)`);
    }
  })
    .then(result => {
      console.log('\n✅ Final result:', result);
    })
    .catch(err => {
      console.error('\n❌ Final failure:', err.message);
    });
}
