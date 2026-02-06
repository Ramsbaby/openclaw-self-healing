#!/usr/bin/env node
/**
 * Level 2: Auto-Tune Cron Script
 *
 * 매일 새벽 3시에 실행:
 * 1. 로그 분석 (log-analyzer)
 * 2. 패턴 감지 → 추천 생성 (parameter-optimizer)
 * 3. 결과 저장 + Discord 알림
 *
 * 자동 적용은 하지 않음 - 추천만 생성하고 알림
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
  timeWindow: 7, // days
  discordWebhook: process.env.OPENCLAW_DISCORD_WEBHOOK || null
};

// ============================================================================
// Main
// ============================================================================

async function main() {
  const startTime = Date.now();
  console.log(`[${new Date().toISOString()}] Level 2 Auto-Tune 시작\n`);

  // Ensure output directory exists
  if (!fs.existsSync(CONFIG.outputDir)) {
    fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  }

  // Step 1: Analyze logs
  console.log('Step 1: 로그 분석...');
  const analyzer = new LogAnalyzer({
    timeWindow: CONFIG.timeWindow * 24 * 3600 * 1000,
    minSampleSize: 5
  });

  let analysis;
  try {
    analysis = await analyzer.analyze(CONFIG.logPath);
    console.log(`  → ${analysis.metadata.analyzedEntries}건 분석 완료`);
  } catch (error) {
    console.error(`  → 분석 실패: ${error.message}`);
    process.exit(1);
  }

  // Save analysis
  const analysisPath = path.join(CONFIG.outputDir, 'analysis-latest.json');
  fs.writeFileSync(analysisPath, JSON.stringify(analysis, null, 2));

  // Step 2: Generate recommendations
  console.log('\nStep 2: 추천 생성...');
  const optimizer = new ParameterOptimizer({
    aggressiveness: 'conservative'
  });

  const recommendations = optimizer.generateRecommendations(
    analysis.patterns,
    analysis.stats,
    analysis.trends
  );

  console.log(`  → ${recommendations.length}건 추천 생성`);

  // Save recommendations
  const recResult = {
    timestamp: new Date().toISOString(),
    analysisId: analysis.metadata.analyzedAt,
    recommendations,
    summary: {
      total: recommendations.length,
      safe: recommendations.filter(r => r.safe).length,
      highSeverity: recommendations.filter(r => r.severity === 'high').length,
      highConfidence: recommendations.filter(r => r.confidence === 'high').length
    },
    stats: {
      totalExecutions: analysis.summary.overall.totalExecutions,
      successRate: analysis.summary.overall.successRate,
      retryRate: analysis.summary.overall.retryRate,
      avgDuration: analysis.summary.overall.avgDuration
    }
  };

  const recPath = path.join(CONFIG.outputDir, 'recommendations-latest.json');
  fs.writeFileSync(recPath, JSON.stringify(recResult, null, 2));

  // Also save timestamped copy for history
  const historyPath = path.join(
    CONFIG.outputDir,
    `recommendations-${new Date().toISOString().split('T')[0]}.json`
  );
  fs.writeFileSync(historyPath, JSON.stringify(recResult, null, 2));

  // Step 3: Print summary
  const duration = Date.now() - startTime;
  console.log('\n' + '='.repeat(50));
  console.log('Level 2 Auto-Tune 결과');
  console.log('='.repeat(50));
  console.log(`실행 시간: ${duration}ms`);
  console.log(`분석 기간: ${CONFIG.timeWindow}일`);
  console.log(`총 실행: ${analysis.summary.overall.totalExecutions}건`);
  console.log(`성공률: ${analysis.summary.overall.successRate}`);
  console.log(`재시도율: ${analysis.summary.overall.retryRate}`);
  console.log(`평균 응답: ${analysis.summary.overall.avgDuration}`);
  console.log(`감지 패턴: ${analysis.patterns.length}건`);
  console.log(`추천: ${recommendations.length}건 (안전: ${recResult.summary.safe}건)`);
  console.log('='.repeat(50));

  if (recommendations.length > 0) {
    console.log('\n추천 목록:');
    recommendations.forEach((rec, i) => {
      const icon = rec.severity === 'high' ? '[HIGH]' : rec.severity === 'medium' ? '[MED]' : '[LOW]';
      const safe = rec.safe ? '[SAFE]' : '[REVIEW]';
      console.log(`  ${i}. ${icon} ${safe} ${rec.cron}: ${rec.param} ${rec.current} → ${rec.proposed}`);
    });
    console.log(`\n적용: node ~/openclaw/scripts/apply-recommendation.js --list`);
  } else {
    console.log('\n모든 파라미터 정상 범위 - 조정 불필요');
  }

  // Step 4: Discord notification (if webhook configured)
  if (CONFIG.discordWebhook && recommendations.length > 0) {
    await sendDiscordNotification(recResult);
  }

  console.log(`\n[${new Date().toISOString()}] 완료 (${duration}ms)`);
}

async function sendDiscordNotification(result) {
  try {
    const message = {
      embeds: [{
        title: 'Level 2 Auto-Tune Report',
        color: result.summary.highSeverity > 0 ? 0xFF0000 : 0x00FF00,
        fields: [
          { name: '실행', value: result.stats.totalExecutions, inline: true },
          { name: '성공률', value: result.stats.successRate, inline: true },
          { name: '추천', value: `${result.summary.total}건`, inline: true },
          { name: '안전', value: `${result.summary.safe}건`, inline: true }
        ],
        timestamp: result.timestamp
      }]
    };

    const response = await fetch(CONFIG.discordWebhook, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(message)
    });

    if (response.ok) {
      console.log('  → Discord 알림 전송 완료');
    }
  } catch (error) {
    console.warn(`  → Discord 알림 실패: ${error.message}`);
  }
}

// ============================================================================
// Run
// ============================================================================

main().catch(error => {
  console.error('Fatal error:', error.message);
  process.exit(1);
});
