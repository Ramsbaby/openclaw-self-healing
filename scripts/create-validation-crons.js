#!/usr/bin/env node
/**
 * Create validation crons for self-evaluating cron jobs
 * 
 * Each validation cron runs 2 minutes after the original cron
 * and validates the self-evaluation output
 */

const { execSync } = require('child_process');

// Cron configurations with their schedules
const SELF_EVAL_CRONS = [
  { id: 'b81588fa-5111-41fb-871f-d767dc1f783b', name: 'Daily Stock Briefing', schedule: '0 6 * * 1-5' },
  { id: 'b9662f08-36ee-4e6d-ab9d-fd2d48f21737', name: '모닝 브리핑', schedule: '15 6 * * 1-5' },
  { id: 'bd8e8994-3646-4f7a-b994-4f3ae9f1890a', name: 'Daily Wrap-up', schedule: '0 17 * * 1-5' },
  { id: 'cc9ddcf5-734c-4e8e-b0e0-51884f8a5196', name: 'Trend Hunter', schedule: '30 12,20 * * *' },
  { id: '41e625c8-59a5-4df5-bd97-2dbc5282eda7', name: 'IT/AI 뉴스 브리핑', schedule: '0 12 * * *' },
  { id: '6b2da787-7df8-49e8-b506-9139f66f86ca', name: '조식 알림', schedule: '55 7 * * 1-5' },
  { id: '422b96a7-8931-43ba-84ce-a55b1b9a6477', name: '취침 알림', schedule: '0 0 * * *' },
  { id: 'e16e5163-9caf-444b-b74d-0cbebaed013b', name: '부부 약 먹기 알림', schedule: '0 22 * * *' },
  { id: 'dfa2bf81-fa94-45b2-a154-b7e4a78fc173', name: '관훈 미확정 저녁', schedule: '0 19 * * *' },
  { id: '270a5dc7-f19e-402f-ae3a-79c628a3cde8', name: 'Monthly DCA', schedule: '0 20 25 * *' },
  { id: '22c071ae-598f-48da-b002-4d1fd395bf0a', name: '실적 발표 캘린더', schedule: '0 8 * * 1' },
  { id: '41e5363d-6b32-48c2-9bf6-738d950c6d6c', name: '주간 요약 리포트', schedule: '0 20 * * 0' },
  { id: 'ddef1a57-21e8-4614-991c-a3f29177e8ee', name: '월간 비용 추적', schedule: '0 9 * * 1' },
  { id: 'a98f06f7-a084-4993-b352-358d00ed340f', name: 'TQQQ 15분 모니터링', schedule: '*/15 * * * *' }
];

/**
 * Add 2 minutes to a cron expression
 */
function addTwoMinutes(cronExpr) {
  const parts = cronExpr.split(' ');
  
  // Handle */N format (e.g., */15)
  if (parts[0].includes('*/')) {
    // For */15, validation would run at 2,17,32,47 (offset by 2)
    const interval = parseInt(parts[0].split('/')[1]);
    parts[0] = `2-59/${interval}`;
    return parts.join(' ');
  }
  
  // Handle range format (e.g., 1-59/15)
  if (parts[0].includes('-') && parts[0].includes('/')) {
    // Already has offset, just adjust
    return parts.join(' ');
  }
  
  // Handle fixed minute
  const minute = parseInt(parts[0]);
  const newMinute = (minute + 2) % 60;
  parts[0] = newMinute.toString();
  
  // If minute wrapped around (58,59 → 0,1), increment hour
  if (newMinute < 2 && minute >= 58) {
    if (parts[1] !== '*' && !parts[1].includes(',') && !parts[1].includes('-')) {
      const hour = parseInt(parts[1]);
      parts[1] = ((hour + 1) % 24).toString();
    }
  }
  
  return parts.join(' ');
}

/**
 * Create validation cron job
 */
function createValidationCron(target) {
  const validationSchedule = addTwoMinutes(target.schedule);
  
  // Determine channel based on target
  // Main user-facing crons go to #jarvis, others to #debug
  const mainCrons = [
    'Daily Stock Briefing',
    '모닝 브리핑',
    'Daily Wrap-up',
    'Trend Hunter',
    'IT/AI 뉴스 브리핑',
    '조식 알림',
    '취침 알림',
    '부부 약 먹기 알림',
    '관훈 미확정 저녁',
    'Monthly DCA',
    '실적 발표 캘린더',
    '주간 요약 리포트',
    '월간 비용 추적',
    'TQQQ 15분 모니터링'
  ];
  const targetChannel = mainCrons.includes(target.name) ? '1468386844621144065' : '1469190688083280065';
  
  const job = {
    name: `🔍 Validation: ${target.name}`,
    enabled: true,
    schedule: {
      kind: 'cron',
      expr: validationSchedule,
      tz: 'Asia/Seoul'
    },
    sessionTarget: 'isolated',
    wakeMode: 'next-heartbeat',
    payload: {
      kind: 'agentTurn',
      model: 'anthropic/claude-haiku-4-5-20251001',
      thinking: 'off',
      channel: 'discord',
      to: `channel:${targetChannel}`,
      deliver: true,
      message: `
🔍 **자기평가 검증: ${target.name}**

**Task:**
1. Discord 채널에서 최근 5분 내 메시지 검색
2. "${target.name}" 크론의 자기평가 섹션 찾기
3. 검증 스크립트 실행

**Steps:**

\`\`\`bash
# 1. Search recent messages (last 5 minutes)
# Use message tool to search Discord channel

# 2. Extract the message with "자기평가 (V2.5)" section

# 3. Save to temp file
echo "[MESSAGE_CONTENT]" > /tmp/cron-validation-input.txt

# 4. Run validation script
node ~/openclaw/scripts/validate-self-review.js \\
  "${target.id}" \\
  "${target.name}" \\
  /tmp/cron-validation-input.txt \\
  0 \\
  0 \\
  0
\`\`\`

**메시지 검색 (message tool 사용):**
- action: search
- channel: discord
- channelId: ${targetChannel}
- query: "자기평가"
- limit: 3

메시지를 찾아서 validate-self-review.js로 검증하세요.

**출력:**
- PASS: NO_REPLY (조용히)
- WARN/INFO: 플래그 요약 (간단히)
- FAIL: 상세 보고 (무엇이 잘못됐는지)

**중요:** 메트릭 수집이 불완전하므로 포맷/일관성 검증에만 집중.
      `.trim()
    }
  };
  
  return job;
}

/**
 * Main function
 */
async function main() {
  console.log('🔍 Creating validation crons for self-evaluating jobs...\n');
  
  let created = 0;
  let failed = 0;
  let skipped = 0;
  
  for (const target of SELF_EVAL_CRONS) {
    try {
      const job = createValidationCron(target);
      const jobJson = JSON.stringify(job).replace(/'/g, "\\'");
      const cmd = `openclaw cron add '${jobJson}'`;
      
      const result = execSync(cmd, { encoding: 'utf8' });
      console.log(`✅ Created validation cron for: ${target.name}`);
      console.log(`   Schedule: ${job.schedule.expr}`);
      created++;
    } catch (e) {
      if (e.message.includes('already exists')) {
        console.log(`⏭️  Skipped (already exists): ${target.name}`);
        skipped++;
      } else {
        console.log(`❌ Failed to create validation cron for ${target.name}:`);
        console.log(`   Error: ${e.message}`);
        failed++;
      }
    }
  }
  
  console.log(`\n📊 Summary:`);
  console.log(`  ✅ Created: ${created}`);
  console.log(`  ⏭️  Skipped: ${skipped}`);
  console.log(`  ❌ Failed: ${failed}`);
  console.log(`  📝 Total: ${SELF_EVAL_CRONS.length}`);
  
  if (created > 0) {
    console.log(`\n✨ Next steps:`);
    console.log(`  1. Wait for next cron execution`);
    console.log(`  2. Check Discord for validation results`);
    console.log(`  3. Review validation-YYYY-MM-DD.jsonl files`);
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { createValidationCron, addTwoMinutes };
