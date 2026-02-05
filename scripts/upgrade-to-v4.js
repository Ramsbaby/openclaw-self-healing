#!/usr/bin/env node
/**
 * Upgrade Self-Review to V4.0
 *
 * Purpose: Update all cron jobs to use self-review-v4.0.md
 * Backup: jobs.json.backup-v4.0-[timestamp]
 */

const fs = require('fs');
const path = require('path');

const JOBS_FILE = path.join(process.env.HOME, '.openclaw/cron/jobs.json');

// Template upgrades
const UPGRADES = [
  {
    from: '~/openclaw/templates/self-review.md',
    to: '~/openclaw/templates/self-review-v4.0.md'
  },
  {
    from: '~/openclaw/templates/self-review-v3.3.md',
    to: '~/openclaw/templates/self-review-v4.0.md'
  },
  {
    from: 'self-review.md',
    to: 'self-review-v4.0.md'
  },
  {
    from: 'self-review-v3.3.md',
    to: 'self-review-v4.0.md'
  }
];

function main() {
  console.log('🔄 Upgrading to Self-Review V4.0\n');

  // Load jobs
  const data = JSON.parse(fs.readFileSync(JOBS_FILE, 'utf8'));
  console.log(`Total jobs: ${data.jobs.length}\n`);

  let updated = 0;

  // Update each job
  data.jobs.forEach(job => {
    let modified = false;

    UPGRADES.forEach(({ from, to }) => {
      if (job.payload.message && job.payload.message.includes(from)) {
        job.payload.message = job.payload.message.replace(new RegExp(from, 'g'), to);
        modified = true;
      }
    });

    if (modified) {
      console.log(`✅ Updated: ${job.name}`);
      updated++;
    }
  });

  console.log(`\n📊 Summary: ${updated} jobs updated\n`);

  // Save
  if (updated > 0) {
    fs.writeFileSync(JOBS_FILE, JSON.stringify(data, null, 2));
    console.log('✅ Saved to:', JOBS_FILE);
    console.log('\n⚠️  Restart OpenClaw Gateway to apply changes:');
    console.log('   openclaw gateway restart\n');
  } else {
    console.log('ℹ️  No updates needed.\n');
  }
}

main();
