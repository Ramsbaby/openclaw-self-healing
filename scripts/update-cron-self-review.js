#!/usr/bin/env node
/**
 * 크론 자기평가 저장 로직 추가 스크립트
 * 각 크론의 메시지에 파일 저장 지시를 추가합니다.
 */

const fs = require('fs');
const path = require('path');

const JOBS_PATH = path.join(process.env.HOME, '.openclaw/cron/jobs.json');

// 업데이트 대상 크론 (TQQQ는 이미 완료)
const TARGET_CRONS = [
  'cc9ddcf5-734c-4e8e-b0e0-51884f8a5196', // Trend Hunter
  'b81588fa-5111-41fb-871f-d767dc1f783b', // Daily Stock Briefing
  '270a5dc7-f19e-402f-ae3a-79c628a3cde8', // Monthly DCA Reminder
  'bd8e8994-3646-4f7a-b994-4f3ae9f1890a', // Daily Wrap-up
  '6b2da787-7df8-49e8-b506-9139f66f86ca', // 조식 알림
  '422b96a7-8931-43ba-84ce-a55b1b9a6477', // 취침 알림
  'b9662f08-36ee-4e6d-ab9d-fd2d48f21737', // 모닝 브리핑
  'e16e5163-9caf-444b-b74d-0cbebaed013b', // 부부 약 먹기 알림
  '41e625c8-59a5-4df5-bd97-2dbc5282eda7', // IT/AI 뉴스 브리핑
  '22c071ae-598f-48da-b002-4d1fd395bf0a', // 실적 발표 캘린더
  'dfa2bf81-fa94-45b2-a154-b7e4a78fc173', // 관훈 미확정 저녁
  '41e5363d-6b32-48c2-9bf6-738d950c6d6c', // 주간 요약 리포트
  'ddef1a57-21e8-4614-991c-a3f29177e8ee', // 월간 비용 추적
];

// 저장 로직 템플릿
const SAVE_INSTRUCTION = `

**📝 저장 (필수):**
자기평가 완료 후 exec 도구로 파일에 저장:
\`\`\`bash
cat >> ~/openclaw/memory/self-review-$(date '+%Y-%m-%d').md << 'EOF'

## HH:MM [크론명]
[여기에 자기평가 전체 내용 복사]
EOF
\`\`\``;

function updateJobs() {
  const data = JSON.parse(fs.readFileSync(JOBS_PATH, 'utf8'));
  let updated = 0;
  
  for (const job of data.jobs) {
    if (!TARGET_CRONS.includes(job.id)) continue;
    
    const msg = job.payload?.message || '';
    
    // 이미 저장 로직이 있으면 스킵
    if (msg.includes('📝 저장 (필수)')) {
      console.log(`⏭️  ${job.name} - 이미 저장 로직 있음`);
      continue;
    }
    
    // "기록: `memory/self-review" 부분을 저장 로직으로 교체
    if (msg.includes('기록: `memory/self-review')) {
      const cronName = job.name.replace(/[[\]]/g, ''); // 특수문자 제거
      const saveInstruction = SAVE_INSTRUCTION.replace('[크론명]', cronName);
      
      job.payload.message = msg.replace(
        /기록: `memory\/self-review-\$\(date '\+%Y-%m-%d'\)\.md`/,
        saveInstruction.trim()
      );
      
      job.updatedAtMs = Date.now();
      updated++;
      console.log(`✅ ${job.name} - 저장 로직 추가`);
    } else {
      console.log(`⚠️  ${job.name} - 기록 패턴 없음, 수동 확인 필요`);
    }
  }
  
  // 백업 후 저장
  const backupPath = JOBS_PATH + '.backup-' + Date.now();
  fs.copyFileSync(JOBS_PATH, backupPath);
  console.log(`\n📦 백업: ${backupPath}`);
  
  fs.writeFileSync(JOBS_PATH, JSON.stringify(data, null, 2));
  console.log(`\n✨ 완료: ${updated}개 크론 업데이트`);
  
  return updated;
}

updateJobs();
