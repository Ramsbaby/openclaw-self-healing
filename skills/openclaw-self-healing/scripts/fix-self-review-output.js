#!/usr/bin/env node
// 자기평가를 사용자에게 보여주지 않도록 크론 메시지 수정

const fs = require('fs');
const path = require('path');

const jobsPath = path.join(process.env.HOME, '.openclaw/cron/jobs.json');
const data = JSON.parse(fs.readFileSync(jobsPath, 'utf8'));

const OLD_TEXT = `## 📊 자기평가 (필수)

\`~/openclaw/templates/self-review.md\` 파일을 읽고 **그 형식 그대로** 출력하라.
파일에 명시된 저장 명령어도 실행할 것.`;

const NEW_TEXT = `## 📊 자기평가 (내부 전용)

\`~/openclaw/templates/self-review.md\`를 참고하여:
1. 품질 체크를 수행하고 \`memory/quality-check-YYYY-MM-DD.md\`에 저장
2. **사용자에게는 절대 출력하지 말 것** (파일 저장만)`;

let updated = 0;

for (const job of data.jobs) {
  if (job.payload && job.payload.message && job.payload.message.includes('자기평가')) {
    const oldMessage = job.payload.message;
    job.payload.message = oldMessage.replace(OLD_TEXT, NEW_TEXT);
    
    if (job.payload.message !== oldMessage) {
      console.log(`✅ 수정: ${job.name}`);
      updated++;
    }
  }
}

fs.writeFileSync(jobsPath, JSON.stringify(data, null, 2));
console.log(`\n총 ${updated}개 크론 수정 완료`);
console.log('Gateway 재시작 필요: openclaw gateway restart');
