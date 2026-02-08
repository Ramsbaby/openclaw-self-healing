#!/usr/bin/env node
/**
 * Level 2: Weekly Analysis (Semi-Automatic)
 *
 * 주간 로그 분석 + 파라미터 조정 제안 생성
 * - 자동 실행 (매주 일요일 23:00)
 * - Discord로 제안 전송
 * - 수동 승인 대기 (자동 적용 안 함)
 */

const path = require('path');
const fs = require('fs');
const { LogAnalyzer } = require('../lib/log-analyzer');
const { ParameterOptimizer } = require('../lib/parameter-optimizer');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  logPath: path.join(process.env.HOME, 'openclaw/logs/auto-retry.jsonl'),
  outputDir: path.join(process.env.HOME, 'openclaw/logs/level2'),
  discordWebhook: process.env.DISCORD_WEBHOOK_URL || process.env.OPENCLAW_DISCORD_WEBHOOK,
  timeWindow: 7 * 24 * 3600 * 1000 // 7 days
};

// ============================================================================
// Discord Notification
// ============================================================================

async function sendDiscordReport(analysis, recommendations) {
  if (!CONFIG.discordWebhook) {
    console.log('⚠️  No Discord webhook configured, skipping notification');
    return;
  }

  const https = require('https');
  const url = new URL(CONFIG.discordWebhook);

  // Build Discord embed
  const embed = {
    title: '📊 Level 2: Weekly Auto-Retry Analysis',
    description: `Analysis period: ${Math.round(CONFIG.timeWindow / (24 * 3600 * 1000))} days`,
    color: recommendations.length > 0 ? 0xFFA500 : 0x00FF00, // Orange if recs, green if none
    fields: [],
    footer: { text: 'Level 2 Parameter Tuning (Semi-Automatic)' },
    timestamp: new Date().toISOString()
  };

  // Overall summary
  embed.fields.push({
    name: '📈 Overall Summary',
    value: [
      `Total Executions: **${analysis.summary.overall.totalExecutions}**`,
      `Success Rate: **${analysis.summary.overall.successRate}**`,
      `Retry Rate: **${analysis.summary.overall.retryRate}**`,
      `Failure Rate: **${analysis.summary.overall.failureRate}**`,
      `Avg Duration: **${analysis.summary.overall.avgDuration}**`
    ].join('\n'),
    inline: false
  });

  // Recommendations
  if (recommendations.length > 0) {
    const recText = recommendations.slice(0, 3).map((rec, i) => {
      const icon = rec.severity === 'high' ? '🔴' : rec.severity === 'medium' ? '🟡' : '🟢';
      const safeIcon = rec.safe ? '✅' : '⚠️';
      return [
        `${i + 1}. ${icon} **${rec.cron}**`,
        `   ${safeIcon} \`${rec.param}\`: ${rec.current} → **${rec.proposed}**`,
        `   📝 ${rec.reason}`,
        `   💡 ${rec.expectedImprovement}`,
        `   🎯 Confidence: ${rec.confidence}`
      ].join('\n');
    }).join('\n\n');

    embed.fields.push({
      name: `💡 Recommendations (${recommendations.length} total)`,
      value: recText + (recommendations.length > 3 ? `\n\n_...and ${recommendations.length - 3} more_` : ''),
      inline: false
    });

    // How to apply
    embed.fields.push({
      name: '🔧 How to Apply',
      value: [
        '```bash',
        '# Review recommendations',
        'cat ~/openclaw/logs/level2/recommendations-latest.json',
        '',
        '# Apply a specific recommendation',
        'node ~/openclaw/scripts/apply-recommendation.js --id=0',
        '```'
      ].join('\n'),
      inline: false
    });
  } else {
    embed.fields.push({
      name: '✅ Status',
      value: 'No optimization needed - all metrics within normal range',
      inline: false
    });
  }

  // Top errors (if any)
  if (analysis.summary.topErrors.length > 0) {
    const errorsText = analysis.summary.topErrors.slice(0, 3).map(e =>
      `- **${e.category}** (${e.count}x): ${e.topType}`
    ).join('\n');

    embed.fields.push({
      name: '🚨 Top Errors',
      value: errorsText,
      inline: false
    });
  }

  // Send to Discord
  const message = { embeds: [embed] };
  const data = JSON.stringify(message);

  return new Promise((resolve, reject) => {
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
        console.log('✅ Discord notification sent');
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
// Main Analysis
// ============================================================================

async function main() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║  📊 Level 2: Weekly Auto-Retry Analysis                  ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  // 1. Ensure output directory exists
  if (!fs.existsSync(CONFIG.outputDir)) {
    fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  }

  // 2. Analyze logs
  console.log('📖 Reading logs...');
  const analyzer = new LogAnalyzer({
    timeWindow: CONFIG.timeWindow,
    minSampleSize: 5 // Low threshold for pattern detection, actual tuning has higher threshold
  });

  const analysis = await analyzer.analyze(CONFIG.logPath);
  console.log(`   ✅ Analyzed ${analysis.metadata.analyzedEntries} entries\n`);

  // 3. Print summary
  analyzer.printResults(analysis);

  // 4. Generate recommendations
  console.log('\n💡 Generating recommendations...');
  const optimizer = new ParameterOptimizer({
    aggressiveness: 'conservative',
    requireStatisticalSignificance: true
  });

  const recommendations = optimizer.generateRecommendations(
    analysis.patterns,
    analysis.stats,
    analysis.trends
  );

  console.log(`   ✅ Generated ${recommendations.length} recommendation(s)\n`);

  // 5. Print recommendations
  if (recommendations.length > 0) {
    console.log('═'.repeat(60));
    console.log('💡 RECOMMENDATIONS');
    console.log('═'.repeat(60) + '\n');

    recommendations.forEach((rec, i) => {
      const icon = rec.severity === 'high' ? '🔴' : rec.severity === 'medium' ? '🟡' : '🟢';
      const safeIcon = rec.safe ? '✅ SAFE' : '⚠️  REVIEW REQUIRED';

      console.log(`${i}. ${icon} ${rec.cron}`);
      console.log(`   Parameter: ${rec.param}`);
      console.log(`   Current:   ${rec.current}`);
      console.log(`   Proposed:  ${rec.proposed}`);
      console.log(`   Reason:    ${rec.reason}`);
      console.log(`   Expected:  ${rec.expectedImprovement}`);
      console.log(`   Severity:  ${rec.severity}`);
      console.log(`   Confidence: ${rec.confidence}`);
      console.log(`   Safety:    ${safeIcon}`);
      if (rec.warning) {
        console.log(`   ⚠️  Warning:  ${rec.warning}`);
      }
      if (rec.recommendation) {
        console.log(`   📝 Note:     ${rec.recommendation}`);
      }
      console.log('');
    });

    console.log('═'.repeat(60));
    console.log('🔧 TO APPLY:');
    console.log('═'.repeat(60));
    console.log('');
    console.log('# Review the recommendations');
    console.log('cat ~/openclaw/logs/level2/recommendations-latest.json');
    console.log('');
    console.log('# Apply a specific recommendation (by index)');
    console.log('node ~/openclaw/scripts/apply-recommendation.js --id=0');
    console.log('');
    console.log('# Apply all safe recommendations');
    console.log('node ~/openclaw/scripts/apply-recommendation.js --all-safe');
    console.log('');
  } else {
    console.log('✅ No recommendations - all metrics within normal range\n');
  }

  // 6. Save results
  const timestamp = new Date().toISOString().replace(/:/g, '-').split('.')[0];
  const outputPath = path.join(CONFIG.outputDir, `recommendations-${timestamp}.json`);
  const latestPath = path.join(CONFIG.outputDir, 'recommendations-latest.json');

  const output = {
    timestamp: new Date().toISOString(),
    analysis: {
      summary: analysis.summary,
      patterns: analysis.patterns,
      trends: analysis.trends,
      metadata: analysis.metadata
    },
    recommendations,
    config: {
      timeWindow: CONFIG.timeWindow,
      aggressiveness: 'conservative'
    }
  };

  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
  fs.writeFileSync(latestPath, JSON.stringify(output, null, 2));

  console.log(`📁 Saved to: ${outputPath}`);
  console.log(`📁 Latest:   ${latestPath}\n`);

  // 7. Send Discord notification
  try {
    await sendDiscordReport(analysis, recommendations);
  } catch (error) {
    console.error('❌ Discord notification failed:', error.message);
  }

  // 8. Summary
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║  ✅ Weekly Analysis Complete                              ║');
  console.log('╚═══════════════════════════════════════════════════════════╝');
  console.log('');
  console.log('Next steps:');
  if (recommendations.length > 0) {
    console.log('  1. Review recommendations in Discord or log file');
    console.log('  2. Apply selected recommendations manually');
    console.log('  3. Monitor results for 24-48 hours');
    console.log('  4. Rollback if needed');
  } else {
    console.log('  - Continue monitoring (no action needed)');
  }
  console.log('');
}

// ============================================================================
// Run
// ============================================================================

if (require.main === module) {
  main().catch(err => {
    console.error('❌ Error:', err.message);
    console.error(err.stack);
    process.exit(1);
  });
}

module.exports = { main };
