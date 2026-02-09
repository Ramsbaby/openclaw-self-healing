#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const jobsPath = path.join(process.env.HOME, '.openclaw/cron/jobs.json');

try {
  // 읽기
  const raw = fs.readFileSync(jobsPath, 'utf8');
  const data = JSON.parse(raw);
  
  let modified = 0;
  
  // isolation 키 제거
  data.jobs.forEach(job => {
    if (job.payload && job.payload.isolation !== undefined) {
      delete job.payload.isolation;
      modified++;
    }
  });
  
  if (modified === 0) {
    console.log('No isolation keys found.');
    process.exit(0);
  }
  
  // 백업
  const backupPath = jobsPath + '.backup-' + Date.now();
  fs.copyFileSync(jobsPath, backupPath);
  console.log(`Backup saved: ${backupPath}`);
  
  // 저장
  fs.writeFileSync(jobsPath, JSON.stringify(data, null, 2), 'utf8');
  console.log(`Removed ${modified} isolation keys from jobs.json`);
  console.log('Gateway restart required: kill -SIGUSR1 $(pgrep -f "openclaw gateway")');
  
} catch (err) {
  console.error('Error:', err.message);
  process.exit(1);
}
