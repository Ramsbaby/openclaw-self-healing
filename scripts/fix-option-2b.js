#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const JOBS_FILE = path.join(process.env.HOME, '.openclaw/cron/jobs.json');

// 파일 기록 지시 생성 함수
function getFileRecordInstruction(cronName) {
  return `

---

**📝 자기평가 기록 (필수):**

위 자기평가를 다음 파일에 저장하세요:
\`memory/self-review-$(date '+%Y-%m-%d').md\`

형식:
\`\`\`markdown
## HH:MM ${cronName}

[위 자기평가 내용 그대로 복사]
\`\`\`

**주의:** 
- 현재 시각은 Asia/Seoul (KST) 기준입니다.
- 파일이 없으면 생성하고, 있으면 추가합니다.`;
}

// 자기평가 포함된 14개 크론
const CRONS_WITH_REVIEW = [
  'b81588fa-5111-41fb-871f-d767dc1f783b', // Daily Stock Briefing
  'b9662f08-36ee-4e6d-ab9d-fd2d48f21737', // 모닝 브리핑
  'bd8e8994-3646-4f7a-b994-4f3ae9f1890a', // Daily Wrap-up
  'cc9ddcf5-734c-4e8e-b0e0-51884f8a5196', // Trend Hunter
  '41e625c8-59a5-4df5-bd97-2dbc5282eda7', // IT/AI 뉴스
  '6b2da787-7df8-49e8-b506-9139f66f86ca', // 조식 알림
  '422b96a7-8931-43ba-84ce-a55b1b9a6477', // 취침 알림
  'e16e5163-9caf-444b-b74d-0cbebaed013b', // 약 먹기
  'dfa2bf81-fa94-45b2-a154-b7e4a78fc173', // 관훈 저녁
  '270a5dc7-f19e-402f-ae3a-79c628a3cde8', // Monthly DCA
  '22c071ae-598f-48da-b002-4d1fd395bf0a', // 실적 발표
  '41e5363d-6b32-48c2-9bf6-738d950c6d6c', // 주간 요약
  'ddef1a57-21e8-4614-991c-a3f29177e8ee', // 월간 비용
  'a98f06f7-a084-4993-b352-358d00ed340f'  // TQQQ 15분
];

try {
  const data = JSON.parse(fs.readFileSync(JOBS_FILE, 'utf8'));
  
  let updated = 0;
  
  data.jobs.forEach(job => {
    if (!CRONS_WITH_REVIEW.includes(job.id)) return;
    
    let message = job.payload.message || '';
    
    // 이미 파일 기록 지시가 있으면 스킵
    if (message.includes('자기평가 기록 (필수)')) {
      console.log(`[SKIP] ${job.name} - 이미 적용됨`);
      return;
    }
    
    // 파일 기록 지시 생성
    const instruction = getFileRecordInstruction(job.name);
    
    // 메시지 끝에 추가
    message = message + instruction;
    
    job.payload.message = message;
    job.updatedAtMs = Date.now();
    updated++;
    console.log(`[UPDATE] ${job.name}`);
  });
  
  fs.writeFileSync(JOBS_FILE, JSON.stringify(data, null, 2));
  console.log(`\n✅ ${updated}개 크론에 파일 기록 지시 추가 완료`);
  
} catch (error) {
  console.error('❌ 에러:', error.message);
  process.exit(1);
}
