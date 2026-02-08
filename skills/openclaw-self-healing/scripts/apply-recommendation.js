#!/usr/bin/env node
/**
 * Level 2: Apply Recommendation (Manual)
 *
 * 사람이 승인 후 파라미터 조정을 수동으로 적용
 * - Rollback point 자동 생성
 * - Atomic file operations
 * - Change log 기록
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  recommendationsPath: path.join(process.env.HOME, 'openclaw/logs/level2/recommendations-latest.json'),
  wrapperDir: path.join(process.env.HOME, 'openclaw/scripts'),
  backupDir: path.join(process.env.HOME, 'openclaw/backups/level2'),
  changeLogPath: path.join(process.env.HOME, 'openclaw/logs/level2/changes.jsonl')
};

// Mapping from cron name to wrapper file
const WRAPPER_MAP = {
  'TQQQ 15분 모니터링': 'tqqq-monitor-with-retry.js',
  'GitHub 감시': 'github-watcher-with-retry.js',
  '일일 주식 브리핑': 'stock-briefing-with-retry.js',
  '시장 급변 감지': 'tqqq-monitor-with-retry.js' // Same as TQQQ
};

// ============================================================================
// Helper Functions
// ============================================================================

function loadRecommendations() {
  if (!fs.existsSync(CONFIG.recommendationsPath)) {
    throw new Error(`Recommendations file not found: ${CONFIG.recommendationsPath}`);
  }

  const data = fs.readFileSync(CONFIG.recommendationsPath, 'utf8');
  const json = JSON.parse(data);

  if (!json.recommendations || json.recommendations.length === 0) {
    throw new Error('No recommendations found');
  }

  return json;
}

function getWrapperPath(cron) {
  const wrapperFile = WRAPPER_MAP[cron];
  if (!wrapperFile) {
    throw new Error(`Unknown cron: ${cron}. Add to WRAPPER_MAP.`);
  }

  return path.join(CONFIG.wrapperDir, wrapperFile);
}

function createBackup(wrapperPath) {
  // Ensure backup directory exists
  if (!fs.existsSync(CONFIG.backupDir)) {
    fs.mkdirSync(CONFIG.backupDir, { recursive: true });
  }

  const timestamp = Date.now();
  const wrapperName = path.basename(wrapperPath);
  const backupPath = path.join(CONFIG.backupDir, `${wrapperName}.${timestamp}.bak`);

  // Create backup
  fs.copyFileSync(wrapperPath, backupPath);

  return {
    timestamp,
    backupPath,
    wrapperPath,
    wrapperName
  };
}

function applyChange(recommendation, wrapperPath) {
  const content = fs.readFileSync(wrapperPath, 'utf8');

  // Different replacement strategies based on parameter
  let updated;

  if (recommendation.param === 'maxRetries') {
    // Match: MAX_RETRIES: 3 (in CONFIG object)
    updated = content.replace(
      /MAX_RETRIES:\s*\d+/g,
      `MAX_RETRIES: ${recommendation.proposed}`
    );
  } else if (recommendation.param === 'timeout') {
    // Match: timeout: 15000 (in spawnSync options)
    updated = content.replace(
      /timeout:\s*\d+/g,
      `timeout: ${recommendation.proposed}`
    );
  } else if (recommendation.param === 'backoffBase') {
    // Match: BACKOFF_BASE: 1000 or baseDelay: 1000
    updated = content.replace(
      /(BACKOFF_BASE|baseDelay):\s*\d+/g,
      `$1: ${recommendation.proposed}`
    );
  } else {
    throw new Error(`Unknown parameter: ${recommendation.param}`);
  }

  // Check if anything changed
  if (updated === content) {
    console.warn(`⚠️  Warning: No changes detected. Pattern may not match.`);
    console.warn(`   Looking for: ${recommendation.param}: ${recommendation.current}`);
  }

  // Atomic write: write to temp file, then rename
  const tempPath = `${wrapperPath}.tmp`;
  fs.writeFileSync(tempPath, updated, 'utf8');
  fs.renameSync(tempPath, wrapperPath);

  return { success: true, changes: updated !== content };
}

function logChange(recommendation, backup) {
  const entry = {
    timestamp: new Date().toISOString(),
    cron: recommendation.cron,
    param: recommendation.param,
    from: recommendation.current,
    to: recommendation.proposed,
    reason: recommendation.reason,
    expectedImprovement: recommendation.expectedImprovement,
    severity: recommendation.severity,
    confidence: recommendation.confidence,
    backup: backup.backupPath,
    appliedBy: 'manual',
    user: process.env.USER || 'unknown'
  };

  // Ensure log directory exists
  const logDir = path.dirname(CONFIG.changeLogPath);
  if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
  }

  // Append to JSONL
  fs.appendFileSync(CONFIG.changeLogPath, JSON.stringify(entry) + '\n');

  return entry;
}

function reloadGateway() {
  try {
    // Check if openclaw gateway is running
    const result = execSync('pgrep -f "openclaw.*gateway" || echo "not_running"', { encoding: 'utf8' });

    if (result.trim() === 'not_running') {
      console.log('ℹ️  OpenClaw Gateway not running, skipping reload');
      return;
    }

    // Gateway is running - it should auto-reload file changes
    // Just log for now
    console.log('ℹ️  OpenClaw Gateway will auto-detect file changes on next cron run');
  } catch (error) {
    console.warn('⚠️  Could not check gateway status:', error.message);
  }
}

// ============================================================================
// Apply Functions
// ============================================================================

async function applySingle(id, dryRun = false) {
  const data = loadRecommendations();
  const recommendation = data.recommendations[id];

  if (!recommendation) {
    throw new Error(`Recommendation #${id} not found (available: 0-${data.recommendations.length - 1})`);
  }

  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║  🔧 Applying Recommendation                               ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  console.log(`ID:         #${id}`);
  console.log(`Cron:       ${recommendation.cron}`);
  console.log(`Parameter:  ${recommendation.param}`);
  console.log(`Change:     ${recommendation.current} → ${recommendation.proposed}`);
  console.log(`Reason:     ${recommendation.reason}`);
  console.log(`Expected:   ${recommendation.expectedImprovement}`);
  console.log(`Severity:   ${recommendation.severity}`);
  console.log(`Confidence: ${recommendation.confidence}`);
  console.log(`Safe:       ${recommendation.safe ? '✅ Yes' : '⚠️  Manual review required'}`);
  console.log('');

  if (recommendation.warning) {
    console.log(`⚠️  WARNING: ${recommendation.warning}`);
    console.log('');
  }

  if (dryRun) {
    console.log('🔍 DRY RUN - No changes will be made\n');
    return;
  }

  // Get wrapper path
  const wrapperPath = getWrapperPath(recommendation.cron);
  console.log(`Wrapper:    ${wrapperPath}`);
  console.log('');

  // Confirm
  if (!process.argv.includes('--yes')) {
    console.log('⚠️  This will modify the wrapper script.');
    console.log('   To proceed without confirmation, use --yes flag');
    console.log('');
    throw new Error('User confirmation required (use --yes to skip)');
  }

  // Create backup
  console.log('📦 Creating backup...');
  const backup = createBackup(wrapperPath);
  console.log(`   ✅ Backup: ${backup.backupPath}\n`);

  // Apply change
  console.log('✏️  Applying change...');
  const result = applyChange(recommendation, wrapperPath);

  if (!result.changes) {
    console.log('   ⚠️  No changes detected (pattern may not match)\n');
  } else {
    console.log('   ✅ Change applied\n');
  }

  // Log change
  console.log('📝 Logging change...');
  const logEntry = logChange(recommendation, backup);
  console.log(`   ✅ Logged to: ${CONFIG.changeLogPath}\n`);

  // Reload gateway
  reloadGateway();

  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║  ✅ Recommendation Applied                                ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  console.log('Next steps:');
  console.log('  1. Monitor auto-retry logs for 24-48 hours');
  console.log('  2. Check for improvements (retry rate, failure rate)');
  console.log('  3. Rollback if needed:');
  console.log(`     cp ${backup.backupPath} ${wrapperPath}`);
  console.log('');
}

async function applyAllSafe(dryRun = false) {
  const data = loadRecommendations();
  const safeRecs = data.recommendations.filter(r => r.safe);

  if (safeRecs.length === 0) {
    console.log('✅ No safe recommendations to apply\n');
    return;
  }

  console.log(`🔧 Applying ${safeRecs.length} safe recommendation(s)...\n`);

  for (let i = 0; i < data.recommendations.length; i++) {
    const rec = data.recommendations[i];
    if (rec.safe) {
      console.log(`─── Recommendation #${i} ───\n`);
      await applySingle(i, dryRun);
      console.log('');
    }
  }

  console.log('✅ All safe recommendations applied\n');
}

async function listRecommendations() {
  const data = loadRecommendations();

  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║  💡 Available Recommendations                             ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  console.log(`Analysis Date: ${new Date(data.timestamp).toLocaleString()}`);
  console.log(`Total: ${data.recommendations.length} recommendation(s)\n`);

  data.recommendations.forEach((rec, i) => {
    const icon = rec.severity === 'high' ? '🔴' : rec.severity === 'medium' ? '🟡' : '🟢';
    const safeIcon = rec.safe ? '✅' : '⚠️';

    console.log(`${i}. ${icon} ${rec.cron}`);
    console.log(`   ${safeIcon} ${rec.param}: ${rec.current} → ${rec.proposed}`);
    console.log(`   ${rec.reason}`);
    console.log(`   Confidence: ${rec.confidence}, Severity: ${rec.severity}`);
    console.log('');
  });

  console.log('To apply:');
  console.log(`  node ${__filename} --id=0 --yes`);
  console.log(`  node ${__filename} --all-safe --yes`);
  console.log('');
}

// ============================================================================
// CLI
// ============================================================================

async function main() {
  const args = process.argv.slice(2);

  // Parse arguments
  const idArg = args.find(a => a.startsWith('--id='));
  const allSafe = args.includes('--all-safe');
  const dryRun = args.includes('--dry-run');
  const list = args.includes('--list') || args.length === 0;

  try {
    if (list) {
      await listRecommendations();
    } else if (idArg) {
      const id = parseInt(idArg.split('=')[1]);
      if (isNaN(id)) {
        throw new Error('Invalid ID (must be number)');
      }
      await applySingle(id, dryRun);
    } else if (allSafe) {
      await applyAllSafe(dryRun);
    } else {
      console.error('Usage:');
      console.error('  --list                 List all recommendations (default)');
      console.error('  --id=N --yes           Apply recommendation #N');
      console.error('  --all-safe --yes       Apply all safe recommendations');
      console.error('  --dry-run              Preview changes without applying');
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

// ============================================================================
// Run
// ============================================================================

if (require.main === module) {
  main();
}

module.exports = { applySingle, applyAllSafe, listRecommendations };
