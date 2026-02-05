#!/usr/bin/env node
/**
 * Level 2: Log Analyzer
 *
 * Auto-Retry 로그를 분석하여 패턴을 감지하고 최적화 제안을 생성
 */

const fs = require('fs');
const readline = require('readline');
const path = require('path');

// ============================================================================
// Log Analyzer Class
// ============================================================================

class LogAnalyzer {
  constructor(options = {}) {
    this.options = {
      timeWindow: options.timeWindow || 7 * 24 * 3600 * 1000, // 7 days default
      minSampleSize: options.minSampleSize || 5, // Minimum samples for pattern detection
      ...options
    };
  }

  /**
   * Analyze auto-retry logs
   * @param {string} logPath - Path to auto-retry.jsonl
   * @returns {Promise<Object>} Analysis results
   */
  async analyze(logPath) {
    const entries = await this.readLog(logPath);
    const filteredEntries = this.filterByTimeWindow(entries);
    const stats = this.calculateStats(filteredEntries);
    const patterns = this.detectPatterns(stats);
    const trends = this.analyzeTrends(filteredEntries);

    return {
      summary: this.generateSummary(stats),
      stats,
      patterns,
      trends,
      metadata: {
        totalEntries: entries.length,
        analyzedEntries: filteredEntries.length,
        timeWindow: this.options.timeWindow,
        analyzedAt: new Date().toISOString()
      }
    };
  }

  /**
   * Read JSONL log file
   * @param {string} logPath - Path to log file
   * @returns {Promise<Array>} Array of log entries
   */
  async readLog(logPath) {
    const entries = [];
    const fileStream = fs.createReadStream(logPath);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity
    });

    for await (const line of rl) {
      if (!line.trim()) continue;

      try {
        const entry = JSON.parse(line);
        entries.push(entry);
      } catch (error) {
        console.error(`Invalid JSON line: ${line.substring(0, 50)}...`);
      }
    }

    return entries;
  }

  /**
   * Filter entries by time window
   * @param {Array} entries - All log entries
   * @returns {Array} Filtered entries
   */
  filterByTimeWindow(entries) {
    const cutoff = Date.now() - this.options.timeWindow;

    return entries.filter(entry => {
      const timestamp = new Date(entry.timestamp).getTime();
      return timestamp >= cutoff;
    });
  }

  /**
   * Calculate statistics from entries
   * @param {Array} entries - Filtered log entries
   * @returns {Object} Statistics
   */
  calculateStats(entries) {
    const stats = {
      overall: {
        total: 0,
        success: 0,
        failure: 0,
        retries: 0,
        retryRate: 0,
        failureRate: 0,
        avgAttempts: 0,
        avgDuration: 0,
        durations: []
      },
      byCron: {},
      byError: {},
      performance: {}
    };

    // Separate actual cron executions from tests
    const cronEntries = entries.filter(e => e.context?.cron);
    const testEntries = entries.filter(e => !e.context?.cron);

    // Analyze cron entries
    for (const entry of cronEntries) {
      const cron = entry.context.cron;

      // Initialize cron stats
      if (!stats.byCron[cron]) {
        stats.byCron[cron] = {
          total: 0,
          success: 0,
          failure: 0,
          retries: 0,
          retryRate: 0,
          failureRate: 0,
          avgAttempts: 0,
          avgDuration: 0,
          durations: [],
          errors: []
        };
      }

      const cronStats = stats.byCron[cron];
      const attempts = entry.attempts.length;
      const duration = entry.totalDuration || 0;

      // Update counts
      stats.overall.total++;
      cronStats.total++;

      if (entry.type === 'success') {
        stats.overall.success++;
        cronStats.success++;
      } else {
        stats.overall.failure++;
        cronStats.failure++;
      }

      if (attempts > 1) {
        stats.overall.retries++;
        cronStats.retries++;
      }

      // Track durations
      stats.overall.durations.push(duration);
      cronStats.durations.push(duration);

      // Track errors
      if (entry.type === 'failure' || attempts > 1) {
        for (const attempt of entry.attempts) {
          if (attempt.error) {
            const errorCategory = attempt.error.category || 'unknown';
            const errorType = attempt.error.type || 'unknown';

            // By error category
            if (!stats.byError[errorCategory]) {
              stats.byError[errorCategory] = {
                count: 0,
                types: {}
              };
            }
            stats.byError[errorCategory].count++;

            // By error type
            if (!stats.byError[errorCategory].types[errorType]) {
              stats.byError[errorCategory].types[errorType] = 0;
            }
            stats.byError[errorCategory].types[errorType]++;

            // Track in cron stats
            cronStats.errors.push({
              category: errorCategory,
              type: errorType,
              message: attempt.error.message
            });
          }
        }
      }
    }

    // Calculate averages and rates
    this.calculateAverages(stats.overall);
    for (const cron in stats.byCron) {
      this.calculateAverages(stats.byCron[cron]);
    }

    // Calculate performance metrics (percentiles)
    stats.performance = this.calculatePerformanceMetrics(stats.overall.durations);

    // Add test stats separately
    stats.tests = {
      total: testEntries.length,
      success: testEntries.filter(e => e.type === 'success').length,
      failure: testEntries.filter(e => e.type === 'failure').length
    };

    return stats;
  }

  /**
   * Calculate averages and rates for a stats object
   * @param {Object} statsObj - Stats object to update
   */
  calculateAverages(statsObj) {
    if (statsObj.total > 0) {
      statsObj.retryRate = statsObj.retries / statsObj.total;
      statsObj.failureRate = statsObj.failure / statsObj.total;
      statsObj.avgAttempts = statsObj.total > 0
        ? (statsObj.total + statsObj.retries) / statsObj.total
        : 0;
    }

    if (statsObj.durations.length > 0) {
      statsObj.avgDuration = statsObj.durations.reduce((a, b) => a + b, 0) / statsObj.durations.length;
    }
  }

  /**
   * Calculate performance metrics (percentiles)
   * @param {Array} durations - Array of durations
   * @returns {Object} Performance metrics
   */
  calculatePerformanceMetrics(durations) {
    if (durations.length === 0) {
      return { p50: 0, p95: 0, p99: 0, min: 0, max: 0 };
    }

    const sorted = [...durations].sort((a, b) => a - b);
    const percentile = (p) => {
      const index = Math.ceil((p / 100) * sorted.length) - 1;
      return sorted[Math.max(0, index)];
    };

    return {
      p50: percentile(50),
      p95: percentile(95),
      p99: percentile(99),
      min: sorted[0],
      max: sorted[sorted.length - 1]
    };
  }

  /**
   * Detect patterns that need attention
   * @param {Object} stats - Statistics object
   * @returns {Array} Array of detected patterns
   */
  detectPatterns(stats) {
    const patterns = [];

    // Pattern detection for each cron
    for (const [cron, data] of Object.entries(stats.byCron)) {
      // Skip if insufficient data
      if (data.total < this.options.minSampleSize) {
        continue;
      }

      // Pattern 1: High retry rate
      if (data.retryRate > 0.10) {
        patterns.push({
          type: 'high_retry_rate',
          severity: data.retryRate > 0.20 ? 'high' : 'medium',
          cron,
          value: data.retryRate,
          threshold: 0.10,
          description: `${(data.retryRate * 100).toFixed(1)}% of executions needed retry (threshold: 10%)`,
          suggestion: 'increase maxRetries',
          affectedExecutions: data.retries
        });
      }

      // Pattern 2: High failure rate
      if (data.failureRate > 0.01) {
        patterns.push({
          type: 'high_failure_rate',
          severity: data.failureRate > 0.05 ? 'high' : 'medium',
          cron,
          value: data.failureRate,
          threshold: 0.01,
          description: `${(data.failureRate * 100).toFixed(1)}% final failure rate (threshold: 1%)`,
          suggestion: 'increase maxRetries or investigate root cause',
          affectedExecutions: data.failure
        });
      }

      // Pattern 3: Slow response (approaching timeout)
      const timeoutThreshold = 15000 * 0.8; // 80% of 15s timeout
      if (data.avgDuration > timeoutThreshold) {
        patterns.push({
          type: 'slow_response',
          severity: data.avgDuration > 15000 * 0.9 ? 'high' : 'medium',
          cron,
          value: data.avgDuration,
          threshold: timeoutThreshold,
          description: `Avg response ${Math.round(data.avgDuration)}ms > 80% of timeout (12s)`,
          suggestion: 'increase timeout',
          currentTimeout: 15000,
          recommendedTimeout: Math.ceil(data.avgDuration * 1.5)
        });
      }

      // Pattern 4: High P95/P99 (inconsistent performance)
      const performance = this.calculatePerformanceMetrics(data.durations);
      if (performance.p95 > performance.p50 * 2) {
        patterns.push({
          type: 'inconsistent_performance',
          severity: 'low',
          cron,
          value: performance.p95 / performance.p50,
          description: `P95 (${Math.round(performance.p95)}ms) is ${(performance.p95 / performance.p50).toFixed(1)}x higher than median`,
          suggestion: 'investigate outliers',
          metrics: performance
        });
      }
    }

    // Pattern 5: Specific error categories
    for (const [category, data] of Object.entries(stats.byError)) {
      if (data.count > 3) {
        const topType = Object.entries(data.types)
          .sort((a, b) => b[1] - a[1])[0];

        patterns.push({
          type: 'recurring_error',
          severity: data.count > 10 ? 'high' : 'medium',
          category,
          value: data.count,
          description: `${category} errors occurred ${data.count} times`,
          topErrorType: topType ? topType[0] : 'unknown',
          suggestion: this.getSuggestionForError(category, topType ? topType[0] : null)
        });
      }
    }

    // Sort by severity
    const severityOrder = { high: 0, medium: 1, low: 2 };
    patterns.sort((a, b) => severityOrder[a.severity] - severityOrder[b.severity]);

    return patterns;
  }

  /**
   * Get suggestion for specific error
   * @param {string} category - Error category
   * @param {string} type - Error type
   * @returns {string} Suggestion
   */
  getSuggestionForError(category, type) {
    const suggestions = {
      'timeout': 'Increase timeout or check network latency',
      'http': type === 'HTTP 429'
        ? 'Increase backoff delay to avoid rate limits'
        : 'Check API status and retry logic',
      'network': 'Check network connectivity and DNS resolution',
      'unknown': 'Investigate error logs for root cause'
    };

    return suggestions[category] || suggestions['unknown'];
  }

  /**
   * Analyze trends over time
   * @param {Array} entries - Filtered log entries
   * @returns {Object} Trend analysis
   */
  analyzeTrends(entries) {
    // Group by day
    const byDay = {};

    for (const entry of entries) {
      if (!entry.context?.cron) continue;

      const date = new Date(entry.timestamp);
      const day = date.toISOString().split('T')[0];
      const cron = entry.context.cron;

      if (!byDay[day]) {
        byDay[day] = {};
      }

      if (!byDay[day][cron]) {
        byDay[day][cron] = {
          total: 0,
          success: 0,
          retries: 0,
          durations: []
        };
      }

      byDay[day][cron].total++;
      if (entry.type === 'success') {
        byDay[day][cron].success++;
      }
      if (entry.attempts.length > 1) {
        byDay[day][cron].retries++;
      }
      byDay[day][cron].durations.push(entry.totalDuration || 0);
    }

    // Calculate daily averages
    const dailyStats = {};
    for (const [day, crons] of Object.entries(byDay)) {
      for (const [cron, data] of Object.entries(crons)) {
        if (!dailyStats[cron]) {
          dailyStats[cron] = [];
        }

        dailyStats[cron].push({
          date: day,
          retryRate: data.retries / data.total,
          avgDuration: data.durations.reduce((a, b) => a + b, 0) / data.durations.length,
          successRate: data.success / data.total
        });
      }
    }

    // Detect trends (improving/degrading)
    const trends = {};
    for (const [cron, days] of Object.entries(dailyStats)) {
      if (days.length < 2) continue;

      // Sort by date
      days.sort((a, b) => a.date.localeCompare(b.date));

      // Simple linear trend (first half vs second half)
      const mid = Math.floor(days.length / 2);
      const firstHalf = days.slice(0, mid);
      const secondHalf = days.slice(mid);

      const avgFirst = {
        retryRate: firstHalf.reduce((a, b) => a + b.retryRate, 0) / firstHalf.length,
        avgDuration: firstHalf.reduce((a, b) => a + b.avgDuration, 0) / firstHalf.length
      };

      const avgSecond = {
        retryRate: secondHalf.reduce((a, b) => a + b.retryRate, 0) / secondHalf.length,
        avgDuration: secondHalf.reduce((a, b) => a + b.avgDuration, 0) / secondHalf.length
      };

      trends[cron] = {
        retryRate: {
          trend: avgSecond.retryRate > avgFirst.retryRate ? 'increasing' : 'decreasing',
          change: ((avgSecond.retryRate - avgFirst.retryRate) / (avgFirst.retryRate || 1)) * 100,
          firstHalf: avgFirst.retryRate,
          secondHalf: avgSecond.retryRate
        },
        avgDuration: {
          trend: avgSecond.avgDuration > avgFirst.avgDuration ? 'increasing' : 'decreasing',
          change: ((avgSecond.avgDuration - avgFirst.avgDuration) / avgFirst.avgDuration) * 100,
          firstHalf: avgFirst.avgDuration,
          secondHalf: avgSecond.avgDuration
        }
      };
    }

    return trends;
  }

  /**
   * Generate human-readable summary
   * @param {Object} stats - Statistics object
   * @returns {Object} Summary
   */
  generateSummary(stats) {
    const summary = {
      overall: {
        totalExecutions: stats.overall.total,
        successRate: `${((stats.overall.success / stats.overall.total) * 100).toFixed(1)}%`,
        retryRate: `${(stats.overall.retryRate * 100).toFixed(1)}%`,
        failureRate: `${(stats.overall.failureRate * 100).toFixed(1)}%`,
        avgAttempts: stats.overall.avgAttempts.toFixed(2),
        avgDuration: `${Math.round(stats.overall.avgDuration)}ms`
      },
      crons: {},
      topErrors: []
    };

    // Summarize each cron
    for (const [cron, data] of Object.entries(stats.byCron)) {
      summary.crons[cron] = {
        executions: data.total,
        successRate: `${((data.success / data.total) * 100).toFixed(1)}%`,
        retryRate: `${(data.retryRate * 100).toFixed(1)}%`,
        avgDuration: `${Math.round(data.avgDuration)}ms`
      };
    }

    // Top errors
    const errorList = Object.entries(stats.byError)
      .map(([category, data]) => ({
        category,
        count: data.count,
        topType: Object.entries(data.types).sort((a, b) => b[1] - a[1])[0]
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);

    summary.topErrors = errorList.map(e => ({
      category: e.category,
      count: e.count,
      topType: e.topType ? e.topType[0] : 'unknown'
    }));

    return summary;
  }

  /**
   * Print analysis results to console
   * @param {Object} analysis - Analysis results
   */
  printResults(analysis) {
    console.log('\n' + '='.repeat(60));
    console.log('📊 Level 2: Auto-Retry Log Analysis');
    console.log('='.repeat(60) + '\n');

    // Summary
    console.log('📈 Overall Summary:');
    console.log(`  Total Executions: ${analysis.summary.overall.totalExecutions}`);
    console.log(`  Success Rate: ${analysis.summary.overall.successRate}`);
    console.log(`  Retry Rate: ${analysis.summary.overall.retryRate}`);
    console.log(`  Failure Rate: ${analysis.summary.overall.failureRate}`);
    console.log(`  Avg Attempts: ${analysis.summary.overall.avgAttempts}`);
    console.log(`  Avg Duration: ${analysis.summary.overall.avgDuration}`);

    // Performance metrics
    if (analysis.stats.performance) {
      const perf = analysis.stats.performance;
      console.log('\n⚡ Performance Metrics:');
      console.log(`  P50 (median): ${Math.round(perf.p50)}ms`);
      console.log(`  P95: ${Math.round(perf.p95)}ms`);
      console.log(`  P99: ${Math.round(perf.p99)}ms`);
      console.log(`  Min: ${Math.round(perf.min)}ms`);
      console.log(`  Max: ${Math.round(perf.max)}ms`);
    }

    // By Cron
    console.log('\n📋 By Cron:');
    for (const [cron, data] of Object.entries(analysis.summary.crons)) {
      console.log(`\n  ${cron}:`);
      console.log(`    Executions: ${data.executions}`);
      console.log(`    Success: ${data.successRate}`);
      console.log(`    Retry: ${data.retryRate}`);
      console.log(`    Avg Duration: ${data.avgDuration}`);
    }

    // Patterns
    if (analysis.patterns.length > 0) {
      console.log('\n⚠️  Detected Patterns:');
      for (const pattern of analysis.patterns) {
        const icon = pattern.severity === 'high' ? '🔴' : pattern.severity === 'medium' ? '🟡' : '🟢';
        console.log(`\n  ${icon} ${pattern.type} (${pattern.severity})`);
        console.log(`    ${pattern.description}`);
        console.log(`    💡 Suggestion: ${pattern.suggestion}`);
      }
    } else {
      console.log('\n✅ No patterns detected - all metrics within normal range');
    }

    // Trends
    if (Object.keys(analysis.trends).length > 0) {
      console.log('\n📈 Trends:');
      for (const [cron, trend] of Object.entries(analysis.trends)) {
        console.log(`\n  ${cron}:`);

        const retryIcon = trend.retryRate.trend === 'increasing' ? '📈' : '📉';
        const retryColor = trend.retryRate.trend === 'increasing' ? '⚠️' : '✅';
        console.log(`    ${retryIcon} Retry Rate: ${retryColor} ${trend.retryRate.trend} (${trend.retryRate.change > 0 ? '+' : ''}${trend.retryRate.change.toFixed(1)}%)`);

        const durationIcon = trend.avgDuration.trend === 'increasing' ? '📈' : '📉';
        const durationColor = trend.avgDuration.trend === 'increasing' ? '⚠️' : '✅';
        console.log(`    ${durationIcon} Avg Duration: ${durationColor} ${trend.avgDuration.trend} (${trend.avgDuration.change > 0 ? '+' : ''}${trend.avgDuration.change.toFixed(1)}%)`);
      }
    }

    // Top errors
    if (analysis.summary.topErrors.length > 0) {
      console.log('\n🚨 Top Errors:');
      for (const error of analysis.summary.topErrors) {
        console.log(`  - ${error.category} (${error.count}x) - ${error.topType}`);
      }
    }

    // Metadata
    console.log('\n' + '='.repeat(60));
    console.log(`Analyzed: ${analysis.metadata.analyzedEntries} entries (${analysis.metadata.totalEntries} total)`);
    console.log(`Time Window: ${Math.round(analysis.metadata.timeWindow / (24 * 3600 * 1000))} days`);
    console.log(`Analyzed At: ${new Date(analysis.metadata.analyzedAt).toLocaleString()}`);
    console.log('='.repeat(60) + '\n');
  }
}

// ============================================================================
// CLI Interface
// ============================================================================

async function main() {
  const logPath = process.argv[2] || path.join(process.env.HOME, 'openclaw/logs/auto-retry.jsonl');
  const timeWindow = parseInt(process.argv[3]) || 7; // days

  console.log(`Analyzing: ${logPath}`);
  console.log(`Time Window: ${timeWindow} days\n`);

  const analyzer = new LogAnalyzer({
    timeWindow: timeWindow * 24 * 3600 * 1000,
    minSampleSize: 5
  });

  try {
    const analysis = await analyzer.analyze(logPath);
    analyzer.printResults(analysis);

    // Save results to file
    const outputPath = path.join(path.dirname(logPath), 'log-analysis.json');
    fs.writeFileSync(outputPath, JSON.stringify(analysis, null, 2));
    console.log(`📁 Full analysis saved to: ${outputPath}\n`);

  } catch (error) {
    console.error('Error analyzing logs:', error.message);
    process.exit(1);
  }
}

// ============================================================================
// Export
// ============================================================================

if (require.main === module) {
  main();
}

module.exports = { LogAnalyzer };
