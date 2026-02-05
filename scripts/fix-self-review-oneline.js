#!/usr/bin/env node
// 자기평가를 한 줄 결과만 보여주도록 수정

const fs = require('fs');
const path = require('path');

const jobsPath = path.join(process.env.HOME, '.openclaw/cron/jobs.json');
const data = JSON.parse(fs.readFileSync(jobsPath, 'utf8'));

const REMOVE_SECTION = /## 📊 자기평가[\s\S]*?(?=\n---|$)/g;

const ADD_INSTRUCTION = `

---

**마지막:** 품질 체크를 \`memory/quality-check-YYYY-MM-DD.md\`에 조용히 저장한 후, 응답 끝에 한 줄만 추가:
✅ 품질: 파일 저장 완료`;

let updated = 0;

for (const job of data.jobs) {
  if (job.payload && job.payload.message && job.payload.message.includes('자기평가')) {
    const oldMessage = job.payload.message;
    
    // 자기평가 섹션 제거
    let newMessage = oldMessage.replace(REMOVE_SECTION, '');
    
    // 새 지시 추가
    newMessage = newMessage.trim() + ADD_INSTRUCTION;
    
    job.payload.message = newMessage;
    
    if (job.payload.message !== oldMessage) {
      console.log(`✅ 수정: ${job.name}`);
      updated++;
    }
  }
}

fs.writeFileSync(jobsPath, JSON.stringify(data, null, 2));
console.log(`\n총 ${updated}개 크론 수정 완료`);
console.log('변경사항은 다음 크론 실행 시 자동 적용됨');
