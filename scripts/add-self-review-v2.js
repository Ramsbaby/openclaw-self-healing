#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const JOBS_FILE = path.join(process.env.HOME, '.openclaw/cron/jobs.json');

// V2: 자기평가를 출력 형식에 포함 (강제)
const SELF_REVIEW_V2 = `

**📊 자기평가 (아래 형식으로 반드시 출력):**
\`\`\`
✅/⚠️ 완성도: [X/5] (누락 항목 명시)
✅/⚠️ 정확성: [OK] or [WARNING: XXX]
✅/⚠️ 톤: [Jarvis] or [ChatGPT-like]
✅/⚠️ 간결성: [X emojis, Y lines]
💡 개선: [다음엔 XXX를 YYY하게]
\`\`\``;

const CRONS_TO_UPDATE = {
  'b81588fa-5111-41fb-871f-d767dc1f783b': { name: 'Daily Stock Briefing' },
  'b9662f08-36ee-4e6d-ab9d-fd2d48f21737': { name: '모닝 브리핑' },
  'bd8e8994-3646-4f7a-b994-4f3ae9f1890a': { name: 'Daily Wrap-up' },
  'cc9ddcf5-734c-4e8e-b0e0-51884f8a5196': { name: 'Trend Hunter' },
  '41e625c8-59a5-4df5-bd97-2dbc5282eda7': { name: 'IT/AI 뉴스 브리핑' },
  '6b2da787-7df8-49e8-b506-9139f66f86ca': { name: '조식 알림' },
  '422b96a7-8931-43ba-84ce-a55b1b9a6477': { name: '취침 알림' },
  'e16e5163-9caf-444b-b74d-0cbebaed013b': { name: '부부 약 먹기 알림' },
  'dfa2bf81-fa94-45b2-a154-b7e4a78fc173': { name: '관훈 미확정 저녁' },
  '270a5dc7-f19e-402f-ae3a-79c628a3cde8': { name: 'Monthly DCA Reminder' },
  '22c071ae-598f-48da-b002-4d1fd395bf0a': { name: '실적 발표 캘린더' },
  '41e5363d-6b32-48c2-9bf6-738d950c6d6c': { name: '주간 요약 리포트' },
  'ddef1a57-21e8-4614-991c-a3f29177e8ee': { name: '월간 비용 추적' },
  'a98f06f7-a084-4993-b352-358d00ed340f': { name: 'TQQQ 15분 모니터링' }
};

try {
  const data = JSON.parse(fs.readFileSync(JOBS_FILE, 'utf8'));
  
  let updated = 0;
  
  data.jobs.forEach(job => {
    const config = CRONS_TO_UPDATE[job.id];
    if (!config) return;
    
    let message = job.payload.message || '';
    
    // V1 자기평가 섹션 제거 (---\n\n**🔍 자기평가 ... 로 시작하는 부분)
    const v1Pattern = /\n---\n\n\*\*🔍 자기평가[\s\S]*$/;
    if (v1Pattern.test(message)) {
      message = message.replace(v1Pattern, '');
      console.log(`[REMOVE V1] ${config.name}`);
    }
    
    // V2 자기평가 추가
    message = message + SELF_REVIEW_V2;
    
    job.payload.message = message;
    job.updatedAtMs = Date.now();
    updated++;
    console.log(`[UPDATE V2] ${config.name}`);
  });
  
  fs.writeFileSync(JOBS_FILE, JSON.stringify(data, null, 2));
  console.log(`\n✅ ${updated}개 크론 V2 업데이트 완료`);
  
} catch (error) {
  console.error('❌ 에러:', error.message);
  process.exit(1);
}
