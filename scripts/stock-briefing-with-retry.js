#!/usr/bin/env node
/**
 * Stock Briefing with Auto-Retry (Level 1 Self-Improvement)
 *
 * Wraps multiple stock analysis scripts with automatic retry
 * Each script gets individual retry handling
 */

const { executeWithRetry } = require('../lib/auto-retry');
const { exec } = require('child_process');
const path = require('path');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  YF_SCRIPT: path.join(process.env.HOME, 'openclaw/skills/yahoo-finance/yf'),
  HOT_SCANNER: path.join(process.env.HOME, 'openclaw/skills/stock-analysis/scripts/hot_scanner.py'),
  RUMOR_SCANNER: path.join(process.env.HOME, 'openclaw/skills/stock-analysis/scripts/rumor_scanner.py'),

  SYMBOLS: ['TQQQ', 'SOXL', 'NVDA'],

  MAX_RETRIES: 3,
  BACKOFF: 'exponential'
};

// ============================================================================
// Execute Command with Retry
// ============================================================================

async function execCommand(command, name) {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();

    exec(command, {
      timeout: 15000,
      maxBuffer: 10 * 1024 * 1024
    }, (error, stdout, stderr) => {
      const duration = Date.now() - startTime;

      if (error) {
        if (error.killed || error.signal === 'SIGTERM') {
          error.code = 'ETIMEDOUT';
        }
        error.duration = duration;
        reject(error);
      } else {
        resolve({
          name,
          output: stdout,
          stderr,
          duration
        });
      }
    });
  });
}

// ============================================================================
// Fetch Stock Quotes
// ============================================================================

async function fetchStockQuotes() {
  console.log('📊 주가 조회 (with Auto-Retry)\n');

  const results = [];

  for (const symbol of CONFIG.SYMBOLS) {
    try {
      console.log(`→ ${symbol}...`);

      const result = await executeWithRetry(
        () => execCommand(`${CONFIG.YF_SCRIPT} ${symbol}`, symbol),
        {
          maxRetries: CONFIG.MAX_RETRIES,
          backoff: CONFIG.BACKOFF,
          context: { task: `fetch ${symbol}` }
        }
      );

      results.push({
        symbol,
        success: true,
        data: result.result,
        attempts: result.attempts
      });

      console.log(`  ✅ ${symbol} (${result.attempts} attempt(s))`);

    } catch (error) {
      results.push({
        symbol,
        success: false,
        error: error.message
      });

      console.error(`  ❌ ${symbol} failed: ${error.message}`);
    }
  }

  return results;
}

// ============================================================================
// Fetch Hot Stocks
// ============================================================================

async function fetchHotStocks() {
  console.log('\n🔥 핫 스캐너 (with Auto-Retry)\n');

  try {
    const result = await executeWithRetry(
      () => execCommand(`python3 ${CONFIG.HOT_SCANNER} --no-social`, 'hot_scanner'),
      {
        maxRetries: CONFIG.MAX_RETRIES,
        backoff: CONFIG.BACKOFF,
        context: { task: 'hot scanner' }
      }
    );

    console.log(`✅ Hot Scanner (${result.attempts} attempt(s))`);
    return { success: true, data: result.result, attempts: result.attempts };

  } catch (error) {
    console.error(`❌ Hot Scanner failed: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// ============================================================================
// Fetch Rumors
// ============================================================================

async function fetchRumors() {
  console.log('\n📰 루머 스캐너 (with Auto-Retry)\n');

  try {
    const result = await executeWithRetry(
      () => execCommand(`python3 ${CONFIG.RUMOR_SCANNER}`, 'rumor_scanner'),
      {
        maxRetries: CONFIG.MAX_RETRIES,
        backoff: CONFIG.BACKOFF,
        context: { task: 'rumor scanner' }
      }
    );

    console.log(`✅ Rumor Scanner (${result.attempts} attempt(s))`);
    return { success: true, data: result.result, attempts: result.attempts };

  } catch (error) {
    console.error(`❌ Rumor Scanner failed: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// ============================================================================
// Main
// ============================================================================

async function main() {
  console.log('📈 일일 주식 브리핑 (with Auto-Retry)\n');
  console.log('='.repeat(60) + '\n');

  const startTime = Date.now();

  // Fetch all data with individual retry handling
  const stockQuotes = await fetchStockQuotes();
  const hotStocks = await fetchHotStocks();
  const rumors = await fetchRumors();

  const totalDuration = Date.now() - startTime;

  // Output results
  console.log('\n' + '='.repeat(60));
  console.log('📊 결과 출력\n');

  // Stock quotes
  for (const quote of stockQuotes) {
    if (quote.success) {
      console.log(`\n${quote.data.output}`);
    } else {
      console.log(`\n❌ ${quote.symbol}: ${quote.error}`);
    }
  }

  // Hot stocks
  if (hotStocks.success) {
    console.log('\n🔥 핫 스톡:\n');
    console.log(hotStocks.data.output);
  }

  // Rumors
  if (rumors.success) {
    console.log('\n📰 루머:\n');
    console.log(rumors.data.output);
  }

  // Summary
  const successCount = stockQuotes.filter(q => q.success).length +
                       (hotStocks.success ? 1 : 0) +
                       (rumors.success ? 1 : 0);
  const totalCount = stockQuotes.length + 2;

  console.log('\n' + '='.repeat(60));
  console.log(`✅ 완료: ${successCount}/${totalCount} 성공`);
  console.log(`⏱️  총 시간: ${totalDuration}ms`);

  // Exit with appropriate code
  process.exit(successCount === totalCount ? 0 : 1);
}

// ============================================================================
// Run
// ============================================================================

if (require.main === module) {
  main();
}

module.exports = { fetchStockQuotes, fetchHotStocks, fetchRumors, CONFIG };
