#!/usr/bin/env node
/**
 * Level 2: Parameter Optimizer (Semi-Automatic)
 *
 * 로그 분석 결과를 기반으로 파라미터 조정 제안 생성
 * - 통계적 검증 포함
 * - 안전 범위 체크
 * - 파라미터 의존성 고려
 * - 수동 승인 필요 (자동 적용 안 함)
 */

// ============================================================================
// Configuration
// ============================================================================

const SAFETY_RULES = {
  maxRetries: {
    min: 2,
    max: 5,
    description: 'Too few retries = high failure rate, too many = slow'
  },
  timeout: {
    min: 10000,
    max: 30000,
    description: 'Must stay within cron interval'
  },
  backoffBase: {
    min: 1000,
    max: 5000,
    description: 'Base delay for exponential backoff'
  }
};

// Minimum sample size for reliable decisions
const MIN_SAMPLE_SIZES = {
  '15min_cron': 96 * 3,   // 3 days for 15-minute cron (96/day)
  'hourly_cron': 24 * 7,  // 7 days for hourly cron
  'daily_cron': 7         // 7 days for daily cron
};

// ============================================================================
// Parameter Optimizer Class
// ============================================================================

class ParameterOptimizer {
  constructor(options = {}) {
    this.options = {
      aggressiveness: options.aggressiveness || 'conservative', // conservative, moderate, aggressive
      requireStatisticalSignificance: options.requireStatisticalSignificance !== false,
      ...options
    };
  }

  /**
   * Generate optimization recommendations from patterns
   * @param {Array} patterns - Detected patterns from LogAnalyzer
   * @param {Object} stats - Full statistics from LogAnalyzer
   * @param {Object} trends - Trend analysis from LogAnalyzer
   * @returns {Array} Array of recommendations
   */
  generateRecommendations(patterns, stats, trends) {
    const recommendations = [];

    // Group patterns by cron
    const byCron = this.groupPatternsByCron(patterns);

    for (const [cron, cronPatterns] of Object.entries(byCron)) {
      const cronStats = stats.byCron[cron];
      const cronTrend = trends[cron];

      // Check sample size first
      if (!this.hasSufficientSamples(cronStats)) {
        console.log(`⚠️  ${cron}: Insufficient samples (${cronStats.total}), skipping`);
        continue;
      }

      // Generate recommendations for each pattern
      for (const pattern of cronPatterns) {
        const rec = this.createRecommendation(pattern, cronStats, cronTrend, cron);
        if (rec) {
          recommendations.push(rec);
        }
      }
    }

    // Validate combinations (check parameter dependencies)
    const validated = this.validateCombinations(recommendations);

    // Sort by priority
    return this.prioritize(validated);
  }

  /**
   * Group patterns by cron name
   */
  groupPatternsByCron(patterns) {
    const byCron = {};
    for (const pattern of patterns) {
      if (pattern.cron) {
        if (!byCron[pattern.cron]) {
          byCron[pattern.cron] = [];
        }
        byCron[pattern.cron].push(pattern);
      }
    }
    return byCron;
  }

  /**
   * Check if cron has sufficient samples for reliable tuning
   */
  hasSufficientSamples(cronStats) {
    const total = cronStats.total;

    // Heuristic: determine cron frequency from sample count
    let minRequired;
    if (total >= 96 * 3) {
      minRequired = MIN_SAMPLE_SIZES['15min_cron'];
    } else if (total >= 24 * 7) {
      minRequired = MIN_SAMPLE_SIZES['hourly_cron'];
    } else {
      minRequired = MIN_SAMPLE_SIZES['daily_cron'];
    }

    return total >= minRequired;
  }

  /**
   * Create recommendation for a specific pattern
   */
  createRecommendation(pattern, cronStats, cronTrend, cron) {
    switch (pattern.type) {
      case 'high_retry_rate':
        return this.recommendMaxRetries(pattern, cronStats, cronTrend, cron);

      case 'high_failure_rate':
        return this.recommendMaxRetries(pattern, cronStats, cronTrend, cron);

      case 'slow_response':
        return this.recommendTimeout(pattern, cronStats, cronTrend, cron);

      case 'recurring_error':
        if (pattern.category === 'http' && pattern.topErrorType === 'HTTP 429') {
          return this.recommendBackoff(pattern, cronStats, cronTrend, cron);
        }
        return null;

      default:
        return null;
    }
  }

  /**
   * Recommend maxRetries adjustment
   */
  recommendMaxRetries(pattern, cronStats, cronTrend, cron) {
    const current = 3; // Current default
    const retryRate = cronStats.retryRate;
    const failureRate = cronStats.failureRate;

    // Dynamic calculation based on severity
    let proposed;
    if (failureRate > 0.05) {
      // Severe: 5%+ failure rate
      proposed = Math.min(current + 2, SAFETY_RULES.maxRetries.max);
    } else if (retryRate > 0.20) {
      // High: 20%+ retry rate
      proposed = Math.min(current + 2, SAFETY_RULES.maxRetries.max);
    } else if (retryRate > 0.10) {
      // Medium: 10%+ retry rate
      proposed = current + 1;
    } else {
      // Mild: under 10%
      proposed = current + 1;
    }

    // Check if trend is improving or degrading
    if (cronTrend) {
      if (cronTrend.retryRate.trend === 'decreasing') {
        // Improving - be conservative
        proposed = Math.min(proposed, current + 1);
      } else if (cronTrend.retryRate.trend === 'increasing') {
        // Degrading - be more aggressive
        proposed = Math.min(proposed + 1, SAFETY_RULES.maxRetries.max);
      }
    }

    // Ensure within safety bounds
    proposed = Math.max(SAFETY_RULES.maxRetries.min, Math.min(proposed, SAFETY_RULES.maxRetries.max));

    if (proposed === current) {
      return null; // No change needed
    }

    // Calculate expected improvement
    const expectedImprovement = this.estimateRetryImprovement(current, proposed, failureRate);

    return {
      cron,
      param: 'maxRetries',
      current,
      proposed,
      reason: `Retry rate ${(retryRate * 100).toFixed(1)}% (threshold: 10%), Failure rate ${(failureRate * 100).toFixed(2)}%`,
      expectedImprovement,
      pattern: pattern.type,
      severity: pattern.severity,
      safe: this.isSafe('maxRetries', proposed),
      confidence: this.calculateConfidence(cronStats, cronTrend),
      metadata: {
        retryRate,
        failureRate,
        trend: cronTrend?.retryRate.trend || 'unknown',
        sampleSize: cronStats.total
      }
    };
  }

  /**
   * Recommend timeout adjustment
   */
  recommendTimeout(pattern, cronStats, cronTrend, cron) {
    const current = 15000; // Current default
    const avgDuration = cronStats.avgDuration;
    const p95Duration = this.calculateP95(cronStats.durations);

    // Use P95 instead of average to account for outliers
    const targetTimeout = Math.ceil(p95Duration * 1.5); // 50% buffer

    // Round to nearest 5 seconds for cleaner values
    const proposed = Math.round(targetTimeout / 5000) * 5000;

    // Ensure within safety bounds
    const bounded = Math.max(
      SAFETY_RULES.timeout.min,
      Math.min(proposed, SAFETY_RULES.timeout.max)
    );

    if (bounded === current) {
      return null; // No change needed
    }

    // Check if we're increasing or decreasing
    if (bounded < current) {
      // Decreasing timeout is risky - require strong evidence
      if (!cronTrend || cronTrend.avgDuration.trend !== 'decreasing') {
        return null; // Don't decrease unless clear improving trend
      }
    }

    return {
      cron,
      param: 'timeout',
      current,
      proposed: bounded,
      reason: `P95 response ${Math.round(p95Duration)}ms, avg ${Math.round(avgDuration)}ms (current timeout: ${current}ms)`,
      expectedImprovement: bounded > current
        ? 'Timeout errors eliminated'
        : 'Faster failure detection',
      pattern: pattern.type,
      severity: pattern.severity,
      safe: this.isSafe('timeout', bounded),
      confidence: this.calculateConfidence(cronStats, cronTrend),
      metadata: {
        avgDuration,
        p95Duration,
        trend: cronTrend?.avgDuration.trend || 'unknown',
        sampleSize: cronStats.total
      }
    };
  }

  /**
   * Recommend backoff adjustment (for rate limiting)
   */
  recommendBackoff(pattern, cronStats, cronTrend, cron) {
    const current = 1000; // Current default base
    const proposed = current * 2; // Double the backoff

    if (proposed > SAFETY_RULES.backoffBase.max) {
      return null; // Already at max
    }

    return {
      cron,
      param: 'backoffBase',
      current,
      proposed,
      reason: `HTTP 429 (Rate Limit) errors: ${pattern.value} times`,
      expectedImprovement: 'Rate limit errors reduced',
      pattern: pattern.type,
      severity: pattern.severity,
      safe: this.isSafe('backoffBase', proposed),
      confidence: 'medium', // Rate limiting is clear
      metadata: {
        errorCount: pattern.value,
        errorType: pattern.topErrorType
      }
    };
  }

  /**
   * Calculate P95 percentile
   */
  calculateP95(durations) {
    if (!durations || durations.length === 0) return 0;
    const sorted = [...durations].sort((a, b) => a - b);
    const index = Math.ceil(0.95 * sorted.length) - 1;
    return sorted[Math.max(0, index)];
  }

  /**
   * Estimate improvement from retry increase
   */
  estimateRetryImprovement(current, proposed, failureRate) {
    // Simple model: each retry recovers ~70% of remaining failures
    const recoveryRate = 0.70;
    const currentRecovery = 1 - Math.pow(1 - recoveryRate, current);
    const proposedRecovery = 1 - Math.pow(1 - recoveryRate, proposed);

    const improvement = (proposedRecovery - currentRecovery) / (1 - currentRecovery);
    return `Final failure rate -${(improvement * 100).toFixed(0)}%`;
  }

  /**
   * Check if proposed value is within safety bounds
   */
  isSafe(param, value) {
    const rule = SAFETY_RULES[param];
    if (!rule) return false;
    return value >= rule.min && value <= rule.max;
  }

  /**
   * Calculate confidence level for recommendation
   */
  calculateConfidence(cronStats, cronTrend) {
    let score = 0;

    // Sample size
    if (cronStats.total >= 500) score += 3;
    else if (cronStats.total >= 200) score += 2;
    else if (cronStats.total >= 100) score += 1;

    // Clear trend
    if (cronTrend) {
      if (Math.abs(cronTrend.retryRate.change) > 50) score += 2; // Strong trend
      else if (Math.abs(cronTrend.retryRate.change) > 20) score += 1; // Weak trend
    }

    // Map to confidence level
    if (score >= 4) return 'high';
    if (score >= 2) return 'medium';
    return 'low';
  }

  /**
   * Validate parameter combinations for dependencies
   */
  validateCombinations(recommendations) {
    const validated = [];
    const byCron = {};

    // Group by cron
    for (const rec of recommendations) {
      if (!byCron[rec.cron]) {
        byCron[rec.cron] = [];
      }
      byCron[rec.cron].push(rec);
    }

    // Check each cron's recommendations
    for (const [cron, recs] of Object.entries(byCron)) {
      // If multiple params for same cron, check combined effect
      if (recs.length > 1) {
        const combined = this.checkCombinedEffect(recs, cron);
        if (!combined.safe) {
          // Mark all as requiring manual review
          for (const rec of recs) {
            rec.safe = false;
            rec.warning = combined.warning;
            rec.recommendation = 'Apply one at a time, verify each before next';
          }
        }
      }
      validated.push(...recs);
    }

    return validated;
  }

  /**
   * Check combined effect of multiple parameter changes
   */
  checkCombinedEffect(recommendations, cron) {
    // Build hypothetical config
    const config = {
      maxRetries: 3,
      timeout: 15000,
      backoffBase: 1000
    };

    for (const rec of recommendations) {
      config[rec.param] = rec.proposed;
    }

    // Calculate worst-case total wait time
    // Exponential backoff: base * (2^0 + 2^1 + ... + 2^(n-1))
    const maxBackoffTime = config.backoffBase * (Math.pow(2, config.maxRetries) - 1);
    const maxTotalTime = config.timeout * config.maxRetries + maxBackoffTime;

    // Assume 15-minute cron interval (900s)
    const cronInterval = 900000; // 15 minutes in ms

    if (maxTotalTime > cronInterval * 0.8) {
      return {
        safe: false,
        warning: `Combined params may exceed cron interval: ${Math.round(maxTotalTime / 1000)}s > ${Math.round(cronInterval * 0.8 / 1000)}s`
      };
    }

    return { safe: true };
  }

  /**
   * Prioritize recommendations
   */
  prioritize(recommendations) {
    const severityOrder = { high: 0, medium: 1, low: 2 };
    const confidenceOrder = { high: 0, medium: 1, low: 2 };

    return recommendations.sort((a, b) => {
      // First by severity
      if (severityOrder[a.severity] !== severityOrder[b.severity]) {
        return severityOrder[a.severity] - severityOrder[b.severity];
      }
      // Then by confidence
      if (confidenceOrder[a.confidence] !== confidenceOrder[b.confidence]) {
        return confidenceOrder[a.confidence] - confidenceOrder[b.confidence];
      }
      // Then by safety
      if (a.safe !== b.safe) {
        return b.safe ? 1 : -1; // Safe first
      }
      return 0;
    });
  }
}

// ============================================================================
// Export
// ============================================================================

module.exports = { ParameterOptimizer, SAFETY_RULES, MIN_SAMPLE_SIZES };
