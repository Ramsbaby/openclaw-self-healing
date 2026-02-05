#!/usr/bin/env node
/**
 * Daily Self-Check Script
 *
 * Purpose: Quick daily review of yesterday's self-evaluations
 * Runs: Daily at 06:00
 *
 * Features:
 * 1. Review yesterday's self-review entries
 * 2. Compare with previous 3 days
 * 3. Detect immediate repetition (< 3 days)
 * 4. Send instant alert if pattern repeats
 *
 * Difference from detect-patterns.js:
 * - detect-patterns.js: Deep analysis, 7-day scan, 3+ threshold
 * - daily-self-check.js: Quick check, 4-day window, instant feedback
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  // Paths
  MEMORY_DIR: path.join(process.env.HOME, 'openclaw', 'memory'),

  // Check window
  DAYS_TO_CHECK: 4, // Yesterday + previous 3 days

  // Similarity
  SIMILARITY_THRESHOLD: 0.65, // Slightly higher for faster detection

  // Discord
  DISCORD_WEBHOOK: 'https://discord.com/api/webhooks/1468429341154214049/arTEGUkhIZ5bpE63AefMnyneomjwf1zDzCpzCwbdlzKpH7KgNzcMpFNX9G-DPW5HRojU',
};

// ============================================================================
// Utilities (imported from detect-patterns.js)
// ============================================================================

function getLastNDays(n) {
  const dates = [];
  for (let i = 0; i < n; i++) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    dates.push(date.toISOString().split('T')[0]);
  }
  return dates;
}

function extractFailures(content) {
  const failures = [];
  const regex = /\*\*이번 실패\/미흡\*\*[^\n]*\n([\s\S]*?)(?=\n\s*│\s*\*\*|╰|$)/g;
  let match;

  while ((match = regex.exec(content)) !== null) {
    const section = match[1];
    const bullets = section.match(/│?\s*[•\-\*]\s*(.+)/g);
    if (bullets) {
      bullets.forEach(bullet => {
        const text = bullet.replace(/│?\s*[•\-\*]\s*/, '').trim();
        if (text && text !== '[구체적 사항]' && text.length > 5) {
          failures.push(text);
        }
      });
    }
  }

  return failures;
}

function extractKeywords(text) {
  const stopwords = ['이', '그', '저', '것', '수', '등', '및', '를', '을', '가', '이', '은', '는', '의', '에', '와', '과'];

  const words = text
    .toLowerCase()
    .replace(/[^\w가-힣\s]/g, ' ')
    .split(/\s+/)
    .filter(w => w.length > 1 && !stopwords.includes(w));

  return [...new Set(words)];
}

function calculateSimilarity(text1, text2) {
  const keywords1 = new Set(extractKeywords(text1));
  const keywords2 = new Set(extractKeywords(text2));

  const intersection = new Set([...keywords1].filter(k => keywords2.has(k)));
  const union = new Set([...keywords1, ...keywords2]);

  return union.size > 0 ? intersection.size / union.size : 0;
}

async function sendDiscordAlert(message) {
  const data = JSON.stringify(message);
  const url = new URL(CONFIG.DISCORD_WEBHOOK);

  const options = {
    hostname: url.hostname,
    path: url.pathname + url.search,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': data.length
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      if (res.statusCode === 204) {
        resolve();
      } else {
        reject(new Error(`Discord API returned ${res.statusCode}`));
      }
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// ============================================================================
// Main Logic
// ============================================================================

async function main() {
  console.log('🌅 Daily Self-Check');
  console.log('===================\n');

  const dates = getLastNDays(CONFIG.DAYS_TO_CHECK);
  const yesterday = dates[0];

  console.log(`Yesterday: ${yesterday}`);
  console.log(`Comparing with: ${dates.slice(1).join(', ')}\n`);

  // 1. Load yesterday's failures
  const yesterdayFile = path.join(CONFIG.MEMORY_DIR, `self-review-${yesterday}.md`);

  if (!fs.existsSync(yesterdayFile)) {
    console.log(`⏭️  No self-review file for ${yesterday}`);
    console.log('This is expected if no cron jobs ran yesterday.\n');
    return;
  }

  const yesterdayContent = fs.readFileSync(yesterdayFile, 'utf8');
  const yesterdayFailures = extractFailures(yesterdayContent);

  console.log(`Yesterday's failures: ${yesterdayFailures.length}\n`);

  if (yesterdayFailures.length === 0) {
    console.log('✅ No failures recorded yesterday. Great job!');
    return;
  }

  // 2. Load previous days' failures
  const previousFailures = [];

  for (const date of dates.slice(1)) {
    const filepath = path.join(CONFIG.MEMORY_DIR, `self-review-${date}.md`);

    if (fs.existsSync(filepath)) {
      const content = fs.readFileSync(filepath, 'utf8');
      const failures = extractFailures(content);

      failures.forEach(text => {
        previousFailures.push({ date, text });
      });

      console.log(`  ${date}: ${failures.length} failures`);
    } else {
      console.log(`  ${date}: (no file)`);
    }
  }

  console.log(`\nPrevious failures total: ${previousFailures.length}\n`);

  // 3. Check for repetitions
  const repetitions = [];

  for (const yesterdayFailure of yesterdayFailures) {
    for (const prevFailure of previousFailures) {
      const similarity = calculateSimilarity(yesterdayFailure, prevFailure.text);

      if (similarity >= CONFIG.SIMILARITY_THRESHOLD) {
        repetitions.push({
          yesterday: yesterdayFailure,
          previous: prevFailure,
          similarity: similarity.toFixed(2)
        });
      }
    }
  }

  console.log(`Repetitions detected: ${repetitions.length}\n`);

  // 4. Alert if repetitions found
  if (repetitions.length > 0) {
    console.log('⚠️  REPEATED FAILURES:\n');

    for (const rep of repetitions) {
      console.log(`  Yesterday: "${rep.yesterday.slice(0, 60)}..."`);
      console.log(`  Previous (${rep.previous.date}): "${rep.previous.text.slice(0, 60)}..."`);
      console.log(`  Similarity: ${(rep.similarity * 100).toFixed(0)}%\n`);
    }

    // Send Discord notification
    try {
      await sendDiscordAlert({
        embeds: [{
          title: '⚠️ 일일 체크: 반복 실패 감지',
          description: `어제(${yesterday}) 기록된 실패/미흡 중 **${repetitions.length}건**이 최근 3일 내 반복되었습니다.`,
          color: 0xFFA500, // Orange
          fields: repetitions.slice(0, 3).map(rep => ({
            name: `반복 패턴 (${rep.previous.date} → ${yesterday})`,
            value: `\`\`\`${rep.yesterday.slice(0, 150)}${rep.yesterday.length > 150 ? '...' : ''}\`\`\``,
            inline: false
          })).concat([{
            name: '권장 조치',
            value: [
              '1. 근본 원인 파악 필요',
              '2. 즉시 개선 항목 재검토',
              '3. 패턴 탐지 스크립트 실행: `node ~/openclaw/scripts/detect-patterns.js`'
            ].join('\n'),
            inline: false
          }]),
          footer: {
            text: 'Daily Self-Check V1.0'
          },
          timestamp: new Date().toISOString()
        }]
      });

      console.log('✅ Discord alert sent\n');
    } catch (e) {
      console.error(`❌ Failed to send Discord alert: ${e.message}\n`);
    }
  } else {
    console.log('✅ No repetitions detected. All failures are new.\n');
  }

  // 5. Summary
  console.log('===================');
  console.log(`Summary: ${yesterdayFailures.length} failures yesterday, ${repetitions.length} repeated`);

  if (repetitions.length > 0) {
    console.log('\n💡 Next steps:');
    console.log('   1. Review repeated failures');
    console.log('   2. Update "즉시 개선" actions');
    console.log('   3. Consider logging to .learnings/');
  }
}

// ============================================================================
// Run
// ============================================================================

if (require.main === module) {
  main().catch(err => {
    console.error('❌ Fatal error:', err);
    process.exit(1);
  });
}

module.exports = { main };
