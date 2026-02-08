#!/usr/bin/env node
/**
 * Auto-Retry Usage Examples
 *
 * Shows how to integrate auto-retry into existing cron jobs
 */

const { executeWithRetry, executeWithNotifications } = require('../lib/auto-retry');
const https = require('https');

// ============================================================================
// Example 1: Simple API Call with Retry
// ============================================================================

async function fetchStockPrice(symbol) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'query1.finance.yahoo.com',
      path: `/v8/finance/chart/${symbol}`,
      method: 'GET',
      timeout: 5000
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          const error = new Error(`HTTP ${res.statusCode}`);
          error.statusCode = res.statusCode;
          reject(error);
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      const error = new Error('Request timeout');
      error.code = 'ETIMEDOUT';
      reject(error);
    });

    req.end();
  });
}

async function example1_SimpleRetry() {
  console.log('Example 1: Simple Retry\n');

  try {
    const result = await executeWithRetry(
      () => fetchStockPrice('TQQQ'),
      {
        maxRetries: 3,
        backoff: 'exponential',
        context: { task: 'fetch TQQQ price' }
      }
    );

    console.log('✅ Success:', result.success);
    console.log('📊 Attempts:', result.attempts);
    console.log('⏱️  Duration:', result.totalDuration + 'ms');
  } catch (error) {
    console.error('❌ Failed:', error.message);
  }
}

// ============================================================================
// Example 2: With Discord Notifications
// ============================================================================

async function example2_WithNotifications() {
  console.log('\nExample 2: With Discord Notifications\n');

  const WEBHOOK = 'https://discord.com/api/webhooks/1468429341154214049/arTEGUkhIZ5bpE63AefMnyneomjwf1zDzCpzCwbdlzKpH7KgNzcMpFNX9G-DPW5HRojU';

  try {
    const result = await executeWithNotifications(
      () => fetchStockPrice('TQQQ'),
      {
        maxRetries: 3,
        backoff: 'exponential',
        discordWebhook: WEBHOOK,
        taskName: 'TQQQ 가격 조회',
        context: { cron: 'TQQQ 15분 모니터링' }
      }
    );

    console.log('✅ Success with notifications');
  } catch (error) {
    console.error('❌ Failed with notifications');
  }
}

// ============================================================================
// Example 3: Wrap Existing Cron Function
// ============================================================================

async function originalCronFunction() {
  // 기존 cron 로직
  const price = await fetchStockPrice('TQQQ');
  const rate = await fetchExchangeRate();

  return {
    price: price.chart.result[0].meta.regularMarketPrice,
    rate
  };
}

async function fetchExchangeRate() {
  // 환율 API 호출
  return 1320.5;
}

async function example3_WrapCron() {
  console.log('\nExample 3: Wrap Existing Cron\n');

  // Before: 재시도 없음
  // const result = await originalCronFunction();

  // After: 자동 재시도 추가
  const result = await executeWithRetry(
    originalCronFunction,
    {
      maxRetries: 3,
      backoff: 'exponential'
    }
  );

  console.log('✅ Cron result:', result.result);
}

// ============================================================================
// Example 4: Custom Retry Logic
// ============================================================================

const { AutoRetry } = require('../lib/auto-retry');

async function example4_CustomLogic() {
  console.log('\nExample 4: Custom Retry Logic\n');

  const retry = new AutoRetry({
    maxRetries: 5,
    backoff: 'linear',
    baseDelay: 2000,  // 2초

    onRetry: async (attempt, error, analysis, delay) => {
      console.log(`  🔄 Retry ${attempt}:`);
      console.log(`     Error: ${error.message}`);
      console.log(`     Category: ${analysis.category}`);
      console.log(`     Suggestion: ${analysis.suggestedFix}`);
      console.log(`     Next attempt in: ${delay}ms\n`);
    },

    onSuccess: async (attempt, result) => {
      if (attempt > 1) {
        console.log(`  ✅ Recovered after ${attempt} attempts!`);
      }
    },

    onFinalFailure: async (attempts, analysis) => {
      console.log(`  ❌ Gave up after ${attempts.length} attempts`);
      console.log(`     Suggestion: ${analysis.suggestedFix}`);

      // 사람에게 알림 (예: Discord, Email 등)
      // await notifyHuman(analysis);
    }
  });

  try {
    const result = await retry.execute(
      () => fetchStockPrice('TQQQ'),
      { task: 'custom retry test' }
    );

    console.log('\n✅ Final success');
  } catch (error) {
    console.error('\n❌ Final failure');
  }
}

// ============================================================================
// Example 5: Integration with TQQQ Monitor
// ============================================================================

async function example5_TQQQIntegration() {
  console.log('\nExample 5: TQQQ Monitor Integration\n');

  const WEBHOOK = 'https://discord.com/api/webhooks/1468429341154214049/arTEGUkhIZ5bpE63AefMnyneomjwf1zDzCpzCwbdlzKpH7KgNzcMpFNX9G-DPW5HRojU';

  // TQQQ 모니터링 로직 (기존 코드와 동일)
  async function monitorTQQQ() {
    const [priceData, rate] = await Promise.all([
      fetchStockPrice('TQQQ'),
      fetchExchangeRate()
    ]);

    const price = priceData.chart.result[0].meta.regularMarketPrice;
    const shares = 47;
    const avgPrice = 52.52;

    const dollarProfit = (price - avgPrice) * shares;
    const wonProfit = dollarProfit * rate;

    return {
      price,
      dollarProfit,
      wonProfit,
      rate
    };
  }

  try {
    // 자동 재시도 + Discord 알림
    const result = await executeWithNotifications(
      monitorTQQQ,
      {
        maxRetries: 3,
        backoff: 'exponential',
        discordWebhook: WEBHOOK,
        taskName: 'TQQQ 15분 모니터링',
        context: {
          cron: 'TQQQ 15분 모니터링',
          schedule: '*/15 * * * *'
        }
      }
    );

    console.log('✅ TQQQ Monitor completed');
    console.log('   Price:', result.result.price);
    console.log('   Dollar P/L:', result.result.dollarProfit.toFixed(2));
    console.log('   Won P/L:', result.result.wonProfit.toFixed(0));
  } catch (error) {
    console.error('❌ TQQQ Monitor failed after all retries');
  }
}

// ============================================================================
// Run Examples
// ============================================================================

async function main() {
  const args = process.argv.slice(2);
  const example = args[0] || 'all';

  if (example === 'all' || example === '1') {
    await example1_SimpleRetry();
  }

  if (example === 'all' || example === '2') {
    await example2_WithNotifications();
  }

  if (example === 'all' || example === '3') {
    await example3_WrapCron();
  }

  if (example === 'all' || example === '4') {
    await example4_CustomLogic();
  }

  if (example === 'all' || example === '5') {
    await example5_TQQQIntegration();
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = {
  example1_SimpleRetry,
  example2_WithNotifications,
  example3_WrapCron,
  example4_CustomLogic,
  example5_TQQQIntegration
};
