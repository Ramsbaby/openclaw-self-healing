#!/usr/bin/env node
/**
 * Self-Review Validation Script (V3 - Stage 2)
 * 
 * Purpose: External validation of self-evaluation results
 * Runs: 1 minute after each self-evaluating cron
 * 
 * Validation Layers:
 * 1. Metric Verification (tool errors, completion time, token usage)
 * 2. Format Verification (emoji count, separator count, forbidden phrases)
 * 3. Consistency Verification (compare with recent evaluations)
 * 
 * Output: validation-YYYY-MM-DD.jsonl
 */

const fs = require('fs');
const path = require('path');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  // Forbidden phrases (from Response Guard)
  FORBIDDEN_PHRASES: [
    '알겠습니다',
    '완료!',
    '완료했습니다',
    '처리했습니다',
    '설정했습니다',
    '확인했습니다',
    '기록했습니다'
  ],
  
  // Format limits
  MAX_EMOJIS: 3,
  MAX_SEPARATORS: 2,
  
  // Metric thresholds
  MAX_TOOL_ERRORS: 2,
  COMPLETION_TIME_MULTIPLIER: 1.5, // 150% of baseline
  TOKEN_USAGE_MULTIPLIER: 1.3, // 130% of baseline
  
  // Paths
  MEMORY_DIR: path.join(process.env.HOME, 'openclaw', 'memory'),
  VALIDATION_DIR: path.join(process.env.HOME, 'openclaw', 'memory'),
  BASELINE_FILE: path.join(process.env.HOME, 'openclaw', 'memory', 'cron-baselines.json')
};

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Count emojis in text
 */
function countEmojis(text) {
  // Unicode emoji ranges
  const emojiRegex = /[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]/gu;
  const matches = text.match(emojiRegex);
  return matches ? matches.length : 0;
}

/**
 * Count markdown separators (---)
 */
function countSeparators(text) {
  const lines = text.split('\n');
  let count = 0;
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed === '---' || /^-{3,}$/.test(trimmed)) {
      count++;
    }
  }
  return count;
}

/**
 * Detect forbidden phrases
 */
function detectForbiddenPhrases(text) {
  const found = [];
  for (const phrase of CONFIG.FORBIDDEN_PHRASES) {
    if (text.includes(phrase)) {
      found.push(phrase);
    }
  }
  return found;
}

/**
 * Parse self-evaluation section from cron output
 */
function parseSelfEvaluation(output) {
  const evalSection = output.match(/##\s*자기평가[\s\S]*?(?=\n##|$)/i);
  if (!evalSection) return null;
  
  const text = evalSection[0];
  const result = {
    completeness: null,
    accuracy: null,
    tone: null,
    conciseness: null,
    improvement: null,
    raw: text
  };
  
  // Parse completeness (e.g., "완성도: 3/3")
  const completenessMatch = text.match(/완성도[:：]\s*(\d+)\/(\d+)/i);
  if (completenessMatch) {
    result.completeness = {
      score: parseInt(completenessMatch[1]),
      total: parseInt(completenessMatch[2])
    };
  }
  
  // Parse accuracy (e.g., "정확성: OK" or "WARNING")
  const accuracyMatch = text.match(/정확성[:：]\s*(OK|WARNING|FAIL)/i);
  if (accuracyMatch) {
    result.accuracy = accuracyMatch[1].toUpperCase();
  }
  
  // Parse tone (e.g., "톤: Jarvis" or "ChatGPT-like")
  const toneMatch = text.match(/톤[:：]\s*(Jarvis|ChatGPT[-\s]?like?)/i);
  if (toneMatch) {
    result.tone = toneMatch[1].toLowerCase().includes('jarvis') ? 'Jarvis' : 'ChatGPT-like';
  }
  
  // Parse conciseness (e.g., "간결성: 2 emojis")
  const concisenessMatch = text.match(/간결성[:：].*?(\d+)\s*emojis?/i);
  if (concisenessMatch) {
    result.conciseness = {
      emojis: parseInt(concisenessMatch[1])
    };
  }
  
  // Parse improvement suggestion
  const improvementMatch = text.match(/개선[:：]\s*(.+)/i);
  if (improvementMatch) {
    result.improvement = improvementMatch[1].trim();
  }
  
  return result;
}

/**
 * Load recent evaluations for consistency check
 */
function loadRecentEvaluations(days = 7) {
  const evaluations = [];
  const now = new Date();
  
  for (let i = 0; i < days; i++) {
    const date = new Date(now);
    date.setDate(date.getDate() - i);
    const dateStr = date.toISOString().split('T')[0];
    const filePath = path.join(CONFIG.VALIDATION_DIR, `validation-${dateStr}.jsonl`);
    
    if (fs.existsSync(filePath)) {
      const lines = fs.readFileSync(filePath, 'utf8').split('\n').filter(l => l.trim());
      for (const line of lines) {
        try {
          evaluations.push(JSON.parse(line));
        } catch (e) {
          // Skip malformed lines
        }
      }
    }
  }
  
  return evaluations;
}

/**
 * Load baseline metrics for a cron
 */
function loadBaseline(cronId) {
  if (!fs.existsSync(CONFIG.BASELINE_FILE)) {
    return null;
  }
  
  const baselines = JSON.parse(fs.readFileSync(CONFIG.BASELINE_FILE, 'utf8'));
  return baselines[cronId] || null;
}

/**
 * Update baseline metrics
 */
function updateBaseline(cronId, metrics) {
  let baselines = {};
  if (fs.existsSync(CONFIG.BASELINE_FILE)) {
    baselines = JSON.parse(fs.readFileSync(CONFIG.BASELINE_FILE, 'utf8'));
  }
  
  if (!baselines[cronId]) {
    baselines[cronId] = {
      samples: [],
      avg: {}
    };
  }
  
  // Add new sample
  baselines[cronId].samples.push({
    timestamp: Date.now(),
    completionTime: metrics.completionTime,
    tokenUsage: metrics.tokenUsage,
    toolErrors: metrics.toolErrors
  });
  
  // Keep only last 30 samples
  if (baselines[cronId].samples.length > 30) {
    baselines[cronId].samples = baselines[cronId].samples.slice(-30);
  }
  
  // Recalculate averages
  const samples = baselines[cronId].samples;
  baselines[cronId].avg = {
    completionTime: samples.reduce((sum, s) => sum + s.completionTime, 0) / samples.length,
    tokenUsage: samples.reduce((sum, s) => sum + s.tokenUsage, 0) / samples.length,
    toolErrors: samples.reduce((sum, s) => sum + s.toolErrors, 0) / samples.length
  };
  
  fs.writeFileSync(CONFIG.BASELINE_FILE, JSON.stringify(baselines, null, 2));
}

// ============================================================================
// Validation Logic
// ============================================================================

/**
 * Validate metrics
 */
function validateMetrics(metrics, baseline) {
  const flags = [];
  
  // Tool errors
  if (metrics.toolErrors > CONFIG.MAX_TOOL_ERRORS) {
    flags.push({
      type: 'HIGH_ERROR_RATE',
      severity: 'HIGH',
      detail: `Tool errors: ${metrics.toolErrors} (threshold: ${CONFIG.MAX_TOOL_ERRORS})`,
      evidence: metrics.toolErrorDetails || []
    });
  }
  
  // Completion time (if baseline exists)
  if (baseline && baseline.avg.completionTime) {
    const threshold = baseline.avg.completionTime * CONFIG.COMPLETION_TIME_MULTIPLIER;
    if (metrics.completionTime > threshold) {
      flags.push({
        type: 'PERFORMANCE_DEGRADATION',
        severity: 'MEDIUM',
        detail: `Completion time: ${metrics.completionTime}ms (baseline avg: ${baseline.avg.completionTime}ms, threshold: ${threshold}ms)`
      });
    }
  }
  
  // Token usage (if baseline exists)
  if (baseline && baseline.avg.tokenUsage) {
    const threshold = baseline.avg.tokenUsage * CONFIG.TOKEN_USAGE_MULTIPLIER;
    if (metrics.tokenUsage > threshold) {
      flags.push({
        type: 'TOKEN_USAGE_HIGH',
        severity: 'LOW',
        detail: `Token usage: ${metrics.tokenUsage} (baseline avg: ${baseline.avg.tokenUsage}, threshold: ${threshold})`
      });
    }
  }
  
  return flags;
}

/**
 * Validate format
 */
function validateFormat(output, selfEval) {
  const flags = [];
  
  // Count actual emojis
  const actualEmojis = countEmojis(output);
  
  // Count actual separators
  const actualSeparators = countSeparators(output);
  
  // Detect forbidden phrases
  const forbiddenFound = detectForbiddenPhrases(output);
  
  // Check emoji count
  if (actualEmojis > CONFIG.MAX_EMOJIS) {
    flags.push({
      type: 'EMOJI_OVERFLOW',
      severity: 'LOW',
      detail: `Actual emojis: ${actualEmojis} (limit: ${CONFIG.MAX_EMOJIS})`
    });
  }
  
  // Check separator count
  if (actualSeparators > CONFIG.MAX_SEPARATORS) {
    flags.push({
      type: 'SEPARATOR_OVERFLOW',
      severity: 'LOW',
      detail: `Actual separators: ${actualSeparators} (limit: ${CONFIG.MAX_SEPARATORS})`
    });
  }
  
  // Check forbidden phrases
  if (forbiddenFound.length > 0) {
    flags.push({
      type: 'FORBIDDEN_PHRASE',
      severity: 'MEDIUM',
      detail: `Forbidden phrases detected: ${forbiddenFound.join(', ')}`
    });
  }
  
  // Check self-eval accuracy
  if (selfEval && selfEval.conciseness) {
    if (selfEval.conciseness.emojis !== actualEmojis) {
      flags.push({
        type: 'INACCURATE_SELF_EVALUATION',
        severity: 'MEDIUM',
        detail: `Self-reported ${selfEval.conciseness.emojis} emojis, actual: ${actualEmojis}`,
        evidence: {
          selfReported: selfEval.conciseness.emojis,
          actual: actualEmojis
        }
      });
    }
  }
  
  return flags;
}

/**
 * Validate consistency
 */
function validateConsistency(selfEval, recentEvals, forbiddenFound) {
  const flags = [];
  
  if (!selfEval) return flags;
  
  // Check tone consistency
  if (selfEval.tone === 'Jarvis' && forbiddenFound.length > 0) {
    flags.push({
      type: 'TONE_MISMATCH',
      severity: 'MEDIUM',
      detail: `Self-reported 'Jarvis' but forbidden phrases detected: ${forbiddenFound.join(', ')}`
    });
  }
  
  // Check accuracy consistency (if recent evals show pattern)
  const recentAccuracyIssues = recentEvals.filter(e => 
    e.selfEvaluation && e.selfEvaluation.accuracy === 'OK' && 
    e.validationFlags.some(f => f.type === 'HIGH_ERROR_RATE')
  );
  
  if (recentAccuracyIssues.length >= 3 && selfEval.accuracy === 'OK') {
    flags.push({
      type: 'ACCURACY_OPTIMISM_BIAS',
      severity: 'LOW',
      detail: `Self-reported 'OK' but recent history shows ${recentAccuracyIssues.length} false OKs in past 7 days`
    });
  }
  
  return flags;
}

// ============================================================================
// Main Validation Function
// ============================================================================

/**
 * Validate a cron execution
 * 
 * @param {Object} input
 * @param {string} input.cronId - Cron job ID
 * @param {string} input.cronName - Cron job name
 * @param {string} input.output - Cron output text
 * @param {Object} input.metrics - Execution metrics
 * @param {number} input.metrics.completionTime - Completion time in ms
 * @param {number} input.metrics.tokenUsage - Token usage
 * @param {number} input.metrics.toolErrors - Number of tool errors
 * @param {Array} input.metrics.toolErrorDetails - Details of tool errors
 */
function validate(input) {
  const { cronId, cronName, output, metrics } = input;
  const timestamp = Date.now();
  
  // Parse self-evaluation
  const selfEval = parseSelfEvaluation(output);
  
  // Load baseline
  const baseline = loadBaseline(cronId);
  
  // Load recent evaluations
  const recentEvals = loadRecentEvaluations(7);
  const recentSameCron = recentEvals.filter(e => e.cronId === cronId);
  
  // Detect forbidden phrases
  const forbiddenFound = detectForbiddenPhrases(output);
  
  // Validate
  const metricFlags = validateMetrics(metrics, baseline);
  const formatFlags = validateFormat(output, selfEval);
  const consistencyFlags = validateConsistency(selfEval, recentSameCron, forbiddenFound);
  
  const allFlags = [...metricFlags, ...formatFlags, ...consistencyFlags];
  
  // Determine verdict
  const verdict = allFlags.length === 0 ? 'PASS' : 
                 allFlags.some(f => f.severity === 'HIGH') ? 'FAIL' :
                 allFlags.some(f => f.severity === 'MEDIUM') ? 'WARN' :
                 'INFO';
  
  // Update baseline
  updateBaseline(cronId, metrics);
  
  // Prepare result
  const result = {
    cronId,
    cronName,
    timestamp,
    selfEvaluation: selfEval,
    validationFlags: allFlags,
    verdict,
    metrics: {
      actual: metrics,
      baseline: baseline ? baseline.avg : null
    },
    formatChecks: {
      emojis: {
        actual: countEmojis(output),
        selfReported: selfEval && selfEval.conciseness ? selfEval.conciseness.emojis : null,
        limit: CONFIG.MAX_EMOJIS
      },
      separators: {
        actual: countSeparators(output),
        limit: CONFIG.MAX_SEPARATORS
      },
      forbiddenPhrases: forbiddenFound
    }
  };
  
  // Write to JSONL
  const dateStr = new Date().toISOString().split('T')[0];
  const outputPath = path.join(CONFIG.VALIDATION_DIR, `validation-${dateStr}.jsonl`);
  fs.appendFileSync(outputPath, JSON.stringify(result) + '\n');
  
  return result;
}

// ============================================================================
// CLI Interface
// ============================================================================

if (require.main === module) {
  // Read input from stdin or command line
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: validate-self-review.js <cronId> <cronName> <outputFile> <completionTime> <tokenUsage> <toolErrors>');
    console.error('   or: cat output.txt | validate-self-review.js <cronId> <cronName> <completionTime> <tokenUsage> <toolErrors>');
    process.exit(1);
  }
  
  let output;
  let cronId, cronName, completionTime, tokenUsage, toolErrors;
  
  // Check if reading from file or stdin
  if (args.length >= 6) {
    // From file
    cronId = args[0];
    cronName = args[1];
    const outputFile = args[2];
    completionTime = parseInt(args[3]);
    tokenUsage = parseInt(args[4]);
    toolErrors = parseInt(args[5]);
    
    output = fs.readFileSync(outputFile, 'utf8');
  } else {
    // From stdin
    cronId = args[0];
    cronName = args[1];
    completionTime = parseInt(args[2]);
    tokenUsage = parseInt(args[3]);
    toolErrors = parseInt(args[4]);
    
    output = fs.readFileSync(0, 'utf8'); // Read from stdin
  }
  
  const result = validate({
    cronId,
    cronName,
    output,
    metrics: {
      completionTime,
      tokenUsage,
      toolErrors,
      toolErrorDetails: []
    }
  });
  
  // Print result
  console.log(JSON.stringify(result, null, 2));
  
  // Exit with error code if FAIL
  if (result.verdict === 'FAIL') {
    process.exit(1);
  }
}

// ============================================================================
// Exports
// ============================================================================

module.exports = {
  validate,
  countEmojis,
  countSeparators,
  detectForbiddenPhrases,
  parseSelfEvaluation,
  loadRecentEvaluations,
  loadBaseline,
  updateBaseline
};
