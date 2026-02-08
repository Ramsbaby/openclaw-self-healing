#!/usr/bin/env node
/**
 * Add Self-Evaluation V2.5 template to cron jobs
 * 
 * Updates 14 cron jobs to include self-evaluation checklist + reflection
 */

const { execSync } = require('child_process');

// Cron IDs that need self-evaluation
const SELF_EVAL_CRONS = [
  { id: 'b81588fa-5111-41fb-871f-d767dc1f783b', name: 'Daily Stock Briefing' },
  { id: 'b9662f08-36ee-4e6d-ab9d-fd2d48f21737', name: '모닝 브리핑' },
  { id: 'bd8e8994-3646-4f7a-b994-4f3ae9f1890a', name: 'Daily Wrap-up' },
  { id: 'cc9ddcf5-734c-4e8e-b0e0-51884f8a5196', name: 'Trend Hunter' },
  { id: '41e625c8-59a5-4df5-bd97-2dbc5282eda7', name: 'IT/AI 뉴스 브리핑' },
  { id: '6b2da787-7df8-49e8-b506-9139f66f86ca', name: '조식 알림' },
  { id: '422b96a7-8931-43ba-84ce-a55b1b9a6477', name: '취침 알림' },
  { id: 'e16e5163-9caf-444b-b74d-0cbebaed013b', name: '부부 약 먹기 알림' },
  { id: 'dfa2bf81-fa94-45b2-a154-b7e4a78fc173', name: '관훈 미확정 저녁' },
  { id: '270a5dc7-f19e-402f-ae3a-79c628a3cde8', name: 'Monthly DCA' },
  { id: '22c071ae-598f-48da-b002-4d1fd395bf0a', name: '실적 발표 캘린더' },
  { id: '41e5363d-6b32-48c2-9bf6-738d950c6d6c', name: '주간 요약 리포트' },
  { id: 'ddef1a57-21e8-4614-991c-a3f29177e8ee', name: '월간 비용 추적' },
  { id: 'a98f06f7-a084-4993-b352-358d00ed340f', name: 'TQQQ 15분 모니터링' }
];

const SELF_EVAL_TEMPLATE = `

---

## 📋 자기평가 (V2.5)

### Pre-Flight Checklist

응답 작성 완료 후, 전송 전 체크:

- [ ] **금지 표현 스캔**: "알겠습니다", "완료!", "처리", "설정", "확인", "기록" 등 포함 여부
- [ ] **이모지 카운트**: 실제 개수 = ? (한도: 3개)
- [ ] **구분선 카운트**: 실제 개수 = ? (한도: 2개)
- [ ] **헤더 간격**: 소제목 앞뒤 빈 줄 1개 확인
- [ ] **도구 에러**: 발생 횟수 = ? (기록)

### 자기평가

✅/⚠️ **완성도**: X/Y [근거: 요구사항 A, B, C 충족]
✅/⚠️ **정확성**: OK/WARNING [근거: 데이터 검증, exit code 0]
✅/⚠️ **톤**: Jarvis/ChatGPT-like [증거: 금지 표현 X개, 위트 포함/미포함]
✅/⚠️ **간결성**: X emojis, Y lines [평가: 적절/과다]
💡 **개선**: 다음엔 [구체적 액션]

### Reflection

**What went well:**
- [성공한 부분 1-2개]

**What went wrong:**
- [문제가 있었던 부분 1-2개, 없으면 "없음"]

**Root cause:**
- [문제의 근본 원인 분석, 없으면 "해당 없음"]

**Next time:**
- [다음 실행 시 개선할 구체적 방법]
`;

// Get current cron jobs
function getCronJobs() {
  const result = execSync('openclaw cron list --json', { encoding: 'utf8' });
  const parsed = JSON.parse(result);
  return parsed.jobs;
}

// Update a cron message
function updateCronMessage(cronId, currentMessage) {
  // Remove existing self-eval section if any
  const cleaned = currentMessage.replace(/\n*---\n*##\s*📋\s*자기평가[\s\S]*$/i, '');
  
  // Add new template
  const newMessage = cleaned + SELF_EVAL_TEMPLATE;
  
  return newMessage;
}

// Main
async function main() {
  console.log('📋 Adding Self-Evaluation V2.5 template to cron jobs...\n');
  console.log('Fetching current cron jobs...');
  const jobs = getCronJobs();
  
  let updated = 0;
  let failed = 0;
  
  for (const target of SELF_EVAL_CRONS) {
    const job = jobs.find(j => j.id === target.id);
    if (!job) {
      console.log(`❌ Cron not found: ${target.name} (${target.id})`);
      failed++;
      continue;
    }
    
    const currentMessage = job.payload.message;
    const newMessage = updateCronMessage(target.id, currentMessage);
    
    // Update via cron tool (requires JSON escaping)
    const patch = {
      payload: {
        message: newMessage
      }
    };
    
    try {
      const cmd = `openclaw cron update ${target.id} '${JSON.stringify(patch).replace(/'/g, "\\'")}'`;
      execSync(cmd, { encoding: 'utf8' });
      console.log(`✅ Updated: ${target.name}`);
      updated++;
    } catch (e) {
      console.log(`❌ Failed to update ${target.name}: ${e.message}`);
      failed++;
    }
  }
  
  console.log(`\n📊 Summary:`);
  console.log(`  ✅ Updated: ${updated}`);
  console.log(`  ❌ Failed: ${failed}`);
  console.log(`  📝 Total: ${SELF_EVAL_CRONS.length}`);
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { updateCronMessage, SELF_EVAL_TEMPLATE };
