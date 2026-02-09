#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const JOBS_FILE = path.join(process.env.HOME, '.openclaw/cron/jobs.json');
const SELF_REVIEW_TEMPLATE = `

---

**🔍 자기평가 (답변 전송 직후 수행):**
1. 완성도: 요청 정보 전부 전달했나?
2. 정확성: 계산/데이터 정확한가?
3. 톤: 자비스답게 건방진가? (ChatGPT처럼 굽신거리지 않았나?)
4. 간결성: 불필요한 말 없었나?
5. 개선점: 다음엔 뭘 더 잘할 수 있나?

→ memory/YYYY-MM-DD.md에 평가 2-3줄 기록 (예: "[HH:MM] 크론명 - ✅/⚠️ 핵심 평가. 개선: XXX")`;

// 업데이트할 크론 ID와 특별 처리
const CRONS_TO_UPDATE = {
  'b81588fa-5111-41fb-871f-d767dc1f783b': {
    name: 'Daily Stock Briefing',
    prependToMessage: `☕ **Good Morning, Sir.**

**💱 환율 (USD/KRW)**
실시간 환율 확인:
\`\`\`bash
python3 ~/openclaw/scripts/get-exchange-rate.py
\`\`\`
→ 현재 환율: ₩X,XXX.XX (전일 대비: ±X.XX원, ±X.XX%)

**📈 포트폴리오 브리핑**
1. **TQQQ / SOXL / NVDA** 간단 시세:
   \`\`\`bash
   ~/openclaw/skills/yahoo-finance/yf TQQQ
   ~/openclaw/skills/yahoo-finance/yf SOXL  
   ~/openclaw/skills/yahoo-finance/yf NVDA
   \`\`\`
2. 지난밤 변동률 요약

**🔥 Hot Scanner** (트렌딩 종목):
   \`\`\`bash
   python3 ~/openclaw/skills/stock-analysis/scripts/hot_scanner.py --no-social
   \`\`\`
   - 상위 3개만 간단히

**🔮 Rumor Scanner** (조기 시그널):
   \`\`\`bash
   python3 ~/openclaw/skills/stock-analysis/scripts/rumor_scanner.py
   \`\`\`
   - Impact 7점 이상만 보고
   - M&A/인수합병 루머, 내부자 거래, 애널리스트 업그레이드

**💡 오늘의 전략** 제안 (Hot + Rumor 종합)`
  },
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
  // Read jobs.json
  const data = JSON.parse(fs.readFileSync(JOBS_FILE, 'utf8'));
  
  let updated = 0;
  
  data.jobs.forEach(job => {
    const config = CRONS_TO_UPDATE[job.id];
    if (!config) return;
    
    const currentMessage = job.payload.message || '';
    
    // 이미 자기평가가 있으면 스킵
    if (currentMessage.includes('🔍 자기평가')) {
      console.log(`[SKIP] ${config.name} - 이미 자기평가 있음`);
      return;
    }
    
    // Daily Stock Briefing은 전체 교체
    if (config.prependToMessage) {
      job.payload.message = config.prependToMessage + SELF_REVIEW_TEMPLATE;
    } else {
      // 나머지는 기존 메시지에 자기평가 추가
      job.payload.message = currentMessage + SELF_REVIEW_TEMPLATE;
    }
    
    job.updatedAtMs = Date.now();
    updated++;
    console.log(`[UPDATE] ${config.name}`);
  });
  
  // Write back
  fs.writeFileSync(JOBS_FILE, JSON.stringify(data, null, 2));
  console.log(`\n✅ ${updated}개 크론 업데이트 완료`);
  
} catch (error) {
  console.error('❌ 에러:', error.message);
  process.exit(1);
}
