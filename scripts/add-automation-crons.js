#!/usr/bin/env node
/**
 * Add Automation Cron Jobs
 *
 * Purpose: Add pattern detection and daily check crons
 */

const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');

const JOBS_FILE = path.join(process.env.HOME, '.openclaw/cron/jobs.json');

const NEW_JOBS = [
  {
    name: '패턴 탐지 (주간)',
    schedule: '0 23 * * 0', // Every Sunday 23:00
    message: `⚙️ **페르소나 지침**
- 모든 응답은 **한국어**로 작성
- 자비스 톤: 정중하지만 약간 건방진 영국식 위트
- 금지 표현: "알겠습니다", "완료", "처리", "Let me", "I'll"

---

🔍 **주간 패턴 탐지**

~/openclaw/scripts/detect-patterns.js 실행.

**목적**: 지난 7일간 반복된 실패/미흡 패턴 탐지
**임계치**: 3회 이상 반복 시 Discord 알림
**출력**: pattern-alerts-YYYY-MM-DD.json

실행 후 결과 요약만 간단히 보고 (한국어로).
패턴 발견 시 주요 개선 제안 포함.`,
    model: 'anthropic/claude-haiku-4-5-20251001',
    channel: '1468429321738911947' // openclaw-health
  },
  {
    name: '일일 자가 체크',
    schedule: '0 6 * * *', // Every day 06:00
    message: `⚙️ **페르소나 지침**
- 모든 응답은 **한국어**로 작성
- 자비스 톤: 정중하지만 약간 건방진 영국식 위트
- 금지 표현: "알겠습니다", "완료", "처리", "Let me", "I'll"

---

🌅 **일일 자가 체크**

~/openclaw/scripts/daily-self-check.js 실행.

**목적**: 어제 self-review 검토, 최근 3일과 비교
**출력**: 반복 패턴 즉시 알림 (Discord)

실행 후:
- 반복 패턴 발견 시: 구체적 개선 제안
- 패턴 없음: NO_REPLY`,
    model: 'anthropic/claude-haiku-4-5-20251001',
    channel: '1468429321738911947' // openclaw-health
  }
];

function main() {
  console.log('➕ Adding Automation Cron Jobs\n');

  // Load jobs
  const data = JSON.parse(fs.readFileSync(JOBS_FILE, 'utf8'));
  console.log(`Current jobs: ${data.jobs.length}\n`);

  // Check if already exists
  const existingNames = data.jobs.map(j => j.name);
  let added = 0;

  NEW_JOBS.forEach(newJob => {
    if (existingNames.includes(newJob.name)) {
      console.log(`⏭️  Skipped: ${newJob.name} (already exists)`);
      return;
    }

    const job = {
      id: randomUUID(),
      agentId: 'main',
      name: newJob.name,
      enabled: true,
      createdAtMs: Date.now(),
      updatedAtMs: Date.now(),
      schedule: {
        kind: 'cron',
        expr: newJob.schedule,
        tz: 'Asia/Seoul'
      },
      sessionTarget: 'isolated',
      wakeMode: 'next-heartbeat',
      payload: {
        deliver: true,
        message: newJob.message,
        channel: 'discord',
        model: newJob.model,
        kind: 'agentTurn',
        to: `channel:${newJob.channel}`,
        thinking: 'off'
      },
      state: {
        nextRunAtMs: 0,
        lastRunAtMs: 0,
        lastStatus: 'pending',
        lastDurationMs: 0
      }
    };

    data.jobs.push(job);
    console.log(`✅ Added: ${newJob.name}`);
    console.log(`   Schedule: ${newJob.schedule}`);
    console.log(`   Model: ${newJob.model}\n`);
    added++;
  });

  console.log(`📊 Summary: ${added} jobs added\n`);

  // Save
  if (added > 0) {
    fs.writeFileSync(JOBS_FILE, JSON.stringify(data, null, 2));
    console.log('✅ Saved to:', JOBS_FILE);
    console.log(`\nTotal jobs: ${data.jobs.length}`);
    console.log('\n⚠️  Restart OpenClaw Gateway to apply changes:');
    console.log('   openclaw gateway restart\n');
  } else {
    console.log('ℹ️  No jobs added.\n');
  }
}

main();
