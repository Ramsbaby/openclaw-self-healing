#!/usr/bin/env node

/**
 * 크론 채널 재분류 스크립트
 * 
 * 채널 매핑:
 * - #jarvis (1468386844621144065): 일상/브리핑
 * - #jarvis-market (1469190686145384513): 투자/뉴스
 * - #jarvis-system (1469190688083280065): 시스템
 */

const CHANNELS = {
  jarvis: 'channel:1468386844621144065',
  market: 'channel:1469190686145384513',
  system: 'channel:1469190688083280065'
};

// 크론 분류 맵 (크론 이름 → 채널)
const CRON_CLASSIFICATION = {
  // #jarvis (일상/브리핑)
  '모닝 브리핑': 'jarvis',
  '검증: 모닝 브리핑': 'jarvis',
  '퇴근 브리핑': 'jarvis',
  '검증: 퇴근 브리핑': 'jarvis',
  '조식 알림': 'jarvis',
  '검증: 조식 알림': 'jarvis',
  '부부 약 먹기 알림': 'jarvis',
  '검증: 부부 약': 'jarvis',
  '취침 알림': 'jarvis',
  '검증: 취침 알림': 'jarvis',
  '관훈 근무일 확인': 'jarvis',
  '관훈 미확정 저녁': 'jarvis',
  '검증: 관훈 저녁': 'jarvis',
  '관훈 예약 알림': 'jarvis',
  '검증: 관훈 예약': 'jarvis',
  '어머님 코다리 알림': 'jarvis',

  // #jarvis-market (투자/뉴스)
  'TQQQ 15분 모니터링': 'market',
  '시장 급변 감지': 'market',
  '일일 주식 브리핑': 'market',
  '검증: 일일 주식': 'market',
  'IT/AI 뉴스 브리핑': 'market',
  '검증: IT/AI 뉴스': 'market',
  '트렌드 헌터': 'market',
  '검증: 트렌드 헌터': 'market',
  '시간당 종합 체크': 'market',
  '실적 발표 캘린더': 'market',
  '검증: 실적 발표': 'market',
  '월급날 정기투자 알림': 'market',
  '검증: 월급날 정기투자': 'market',
  '자비스 정보 탐험': 'market',
  '주간 요약 리포트': 'market',
  '검증: 주간 요약': 'market',
  'GitHub 감시': 'market',

  // #jarvis-system (시스템)
  '🚨 Emergency Recovery 실패 감지': 'system',
  '외부 API 사용량 모니터링': 'system',
  '일일 백업': 'system',
  'Kakao 에러 로그 정리': 'system',
  'Nightly Build': 'system',
  '로그 정리': 'system',
  '디스크 용량 경고': 'system',
  '일일 닥터 점검': 'system',
  '일일 자가 체크': 'system',
  'Kakao Token 자동 갱신': 'system',
  'Kakao Refresh Token 만료 알림': 'system',
  '일일 업데이트 확인': 'system',
  '월간 비용 추적': 'system',
  '검증: 월간 비용': 'system',
  '크론 감시 리포트': 'system',
  '야간 종합 점검': 'system',
  '일일 자가개선': 'system',
  '패턴 탐지 (주간)': 'system',
  '주간 자기평가 감사': 'system'
};

async function main() {
  const gatewayUrl = 'http://localhost:18789';
  
  // 1. 모든 크론 가져오기
  const listRes = await fetch(`${gatewayUrl}/api/cron/list`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'list' })
  });
  
  const { jobs } = await listRes.json();
  
  console.log(`총 ${jobs.length}개 크론 발견\n`);
  
  let updated = 0;
  let skipped = 0;
  let errors = 0;
  
  for (const job of jobs) {
    const targetChannel = CRON_CLASSIFICATION[job.name];
    
    if (!targetChannel) {
      console.log(`⏭️  스킵: "${job.name}" (분류 없음)`);
      skipped++;
      continue;
    }
    
    const newChannelId = CHANNELS[targetChannel];
    const currentTo = job.payload?.to;
    
    if (currentTo === newChannelId) {
      console.log(`✅ 이미 올바름: "${job.name}" → ${targetChannel}`);
      skipped++;
      continue;
    }
    
    // payload 복사 및 to 업데이트
    const updatedPayload = {
      ...job.payload,
      to: newChannelId
    };
    
    try {
      const updateRes = await fetch(`${gatewayUrl}/api/cron/update`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'update',
          jobId: job.id,
          patch: { payload: updatedPayload }
        })
      });
      
      const result = await updateRes.json();
      
      if (result.error) {
        console.error(`❌ 실패: "${job.name}" - ${result.error}`);
        errors++;
      } else {
        console.log(`🔄 업데이트: "${job.name}" → ${targetChannel} (${currentTo || 'null'} → ${newChannelId})`);
        updated++;
      }
    } catch (err) {
      console.error(`❌ 예외: "${job.name}" - ${err.message}`);
      errors++;
    }
  }
  
  console.log(`\n📊 결과:`);
  console.log(`   업데이트: ${updated}개`);
  console.log(`   스킵: ${skipped}개`);
  console.log(`   에러: ${errors}개`);
}

main().catch(console.error);
