#!/usr/bin/env node
/**
 * Demo: Auto-Retry with Simulated Failures
 *
 * Shows retry behavior with controlled failure rates
 */

const { executeWithRetry } = require('../lib/auto-retry');

let attemptCount = 0;

// Simulated function that fails first 2 times, succeeds on 3rd
async function unreliableFunction() {
  attemptCount++;
  console.log(`  → Attempt ${attemptCount}...`);

  if (attemptCount < 3) {
    // Simulate network timeout
    const error = new Error('Simulated network timeout');
    error.code = 'ETIMEDOUT';
    throw error;
  }

  // Success on 3rd try
  return { data: 'Success!', attempt: attemptCount };
}

async function demo() {
  console.log('🔄 Auto-Retry Demo\n');
  console.log('Simulating unreliable API (fails 2x, succeeds on 3rd)...\n');

  attemptCount = 0;  // Reset

  try {
    const result = await executeWithRetry(
      unreliableFunction,
      {
        maxRetries: 5,
        backoff: 'exponential',
        baseDelay: 500,
        context: { demo: 'simulated failure' },

        onRetry: (attempt, error, analysis, delay) => {
          console.log(`\n⚠️  Retry ${attempt}:`);
          console.log(`   Error: ${error.message}`);
          console.log(`   Category: ${analysis.category}`);
          console.log(`   Retryable: ${analysis.retryable}`);
          console.log(`   Suggestion: ${analysis.suggestedFix}`);
          console.log(`   Waiting: ${delay}ms`);
        }
      }
    );

    console.log('\n✅ Final Success!');
    console.log(`   Result: ${JSON.stringify(result.result)}`);
    console.log(`   Total attempts: ${result.attempts}`);
    console.log(`   Total duration: ${result.totalDuration}ms`);

  } catch (error) {
    console.log('\n❌ Final Failure!');
    console.log(`   Error: ${error.message}`);
  }
}

demo();
