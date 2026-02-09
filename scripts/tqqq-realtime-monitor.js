#!/usr/bin/env node
/**
 * TQQQ 실시간 모니터 (크론용)
 * 
 * Finnhub REST API로 실시간 가격 조회 (무료 플랜)
 * Auto-retry 포함
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  FINNHUB_API_KEY: process.env.FINNHUB_API_KEY || 
    JSON.parse(fs.readFileSync(path.join(process.env.HOME, '.openclaw/openclaw.json'), 'utf8'))
      .env?.FINNHUB_API_KEY,
  
  SYMBOL: 'TQQQ',
  MAX_RETRIES: 3,
  TIMEOUT: 10000, // 10초
  
  // 환율 (실시간 조회 가능하면 업그레이드)
  USD_KRW: 1465.09
};

// ============================================================================
// Finnhub API 호출
// ============================================================================

function fetchFinnhubQuote(symbol) {
  return new Promise((resolve, reject) => {
    const url = `https://finnhub.io/api/v1/quote?symbol=${symbol}&token=${CONFIG.FINNHUB_API_KEY}`;
    
    const req = https.get(url, {
      timeout: CONFIG.TIMEOUT
    }, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          
          // Finnhub는 에러 시에도 200 리턴하고 error 필드 포함
          if (json.error) {
            reject(new Error(`Finnhub API error: ${json.error}`));
          } else if (json.c !== undefined) {
            resolve(json);
          } else {
            reject(new Error('Invalid response from Finnhub'));
          }
        } catch (error) {
          reject(new Error(`JSON parse error: ${error.message}`));
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
  });
}

// ============================================================================
// Retry Logic
// ============================================================================

async function fetchWithRetry(symbol, maxRetries = 3) {
  let lastError;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`🔄 Attempt ${attempt}/${maxRetries}...`);
      const result = await fetchFinnhubQuote(symbol);
      console.log(`✅ Success on attempt ${attempt}`);
      return result;
    } catch (error) {
      lastError = error;
      console.error(`❌ Attempt ${attempt} failed: ${error.message}`);
      
      if (attempt < maxRetries) {
        const delay = Math.min(1000 * Math.pow(2, attempt - 1), 5000);
        console.log(`⏳ Retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  
  throw lastError;
}

// ============================================================================
// Market Status
// ============================================================================

function getMarketStatus() {
  const now = new Date();
  const estOffset = -5 * 60; // EST = UTC-5
  const estTime = new Date(now.getTime() + (estOffset + now.getTimezoneOffset()) * 60000);
  
  const day = estTime.getDay(); // 0=일, 6=토
  const hour = estTime.getHours();
  const minute = estTime.getMinutes();
  const totalMinutes = hour * 60 + minute;
  
  // 주말
  if (day === 0 || day === 6) {
    return { status: 'closed', label: '⏸️ 주말 휴장 - 마지막 종가' };
  }
  
  // 정규장: 09:30 - 16:00 EST
  if (totalMinutes >= 9 * 60 + 30 && totalMinutes < 16 * 60) {
    return { status: 'market', label: '🟢 정규장 실시간' };
  }
  
  // 애프터마켓: 16:00 - 20:00 EST
  if (totalMinutes >= 16 * 60 && totalMinutes < 20 * 60) {
    return { status: 'aftermarket', label: '🟡 애프터마켓 종가' };
  }
  
  // 프리마켓: 04:00 - 09:30 EST
  if (totalMinutes >= 4 * 60 && totalMinutes < 9 * 60 + 30) {
    return { status: 'premarket', label: '🟠 프리마켓 가격' };
  }
  
  // 장 마감: 20:00 - 04:00 EST
  return { status: 'closed', label: '⏸️ 장 마감 - 마지막 종가' };
}

function getNextMarketOpen() {
  const now = new Date();
  const kstTime = new Date(now.getTime() + (9 * 60 * 60 * 1000)); // KST = UTC+9
  
  // 다음 정규장 시작: 09:30 EST = 23:30 KST
  const nextOpen = new Date(kstTime);
  nextOpen.setHours(23, 30, 0, 0);
  
  // 이미 지났으면 내일
  if (kstTime.getHours() >= 23 && kstTime.getMinutes() >= 30) {
    nextOpen.setDate(nextOpen.getDate() + 1);
  }
  
  // 주말이면 다음 월요일
  const day = nextOpen.getDay();
  if (day === 0) nextOpen.setDate(nextOpen.getDate() + 1); // 일요일 → 월요일
  if (day === 6) nextOpen.setDate(nextOpen.getDate() + 2); // 토요일 → 월요일
  
  return nextOpen.toLocaleString('ko-KR', { 
    timeZone: 'Asia/Seoul',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

// ============================================================================
// Format Output
// ============================================================================

function formatOutput(data) {
  const currentPrice = data.c;  // Current price
  const change = data.d;        // Change
  const changePercent = data.dp; // Change percent
  const high = data.h;          // Day high
  const low = data.l;           // Day low
  const open = data.o;          // Day open
  const prevClose = data.pc;    // Previous close
  const timestamp = new Date(data.t * 1000); // Unix timestamp to JS Date
  
  const krwPrice = Math.round(currentPrice * CONFIG.USD_KRW);
  const krwLow = Math.round(low * CONFIG.USD_KRW);
  const krwHigh = Math.round(high * CONFIG.USD_KRW);
  
  const marketStatus = getMarketStatus();
  
  // MEMORY.md에서 포지션 정보 읽기
  let position = null;
  try {
    const memoryPath = path.join(process.env.HOME, 'openclaw/MEMORY.md');
    const memoryContent = fs.readFileSync(memoryPath, 'utf8');
    
    // "현재 상황:" 섹션 파싱
    const statusMatch = memoryContent.match(/현재 상황:\s*(.+?)(?=\n\n|\n\*\*)/s);
    if (statusMatch) {
      const statusText = statusMatch[1];
      
      if (statusText.includes('재진입 대기')) {
        position = { type: 'waiting', cash: '$9,000' };
      } else if (statusText.includes('손절 완료')) {
        position = { type: 'exited', cash: '$9,000' };
      }
    }
  } catch (error) {
    console.error(`⚠️ Failed to read MEMORY.md: ${error.message}`);
  }
  
  // 출력
  console.log('\n📊 TQQQ 스냅샷 (Finnhub API)\n');
  console.log(`${marketStatus.label}\n`);
  console.log('╭─────────────────┬───────────────────╮');
  console.log('│ 항목            │ 값                │');
  console.log('├─────────────────┼───────────────────┤');
  console.log(`│ 현재가 (USD)    │ $${currentPrice.toFixed(2).padStart(15)} │`);
  console.log(`│ 현재가 (KRW)    │ ₩${krwPrice.toLocaleString('ko-KR').padStart(15)} │`);
  console.log(`│ 전일 종가       │ $${prevClose.toFixed(2).padStart(15)} │`);
  
  const changeIcon = change >= 0 ? '▲' : '▼';
  const changeColor = change >= 0 ? '' : '';
  console.log(`│ 변동 (전일比)   │ ${changeIcon} $${Math.abs(change).toFixed(2)} (${changePercent.toFixed(2)}%)${' '.repeat(Math.max(0, 5 - changePercent.toFixed(2).length))} │`);
  
  console.log(`│ 일중 범위       │ $${low.toFixed(2)} ~ $${high.toFixed(2)}${' '.repeat(Math.max(0, 4 - (low.toFixed(2).length + high.toFixed(2).length)))} │`);
  console.log(`│ 일중 범위 (KRW) │ ₩${krwLow.toLocaleString('ko-KR')} ~ ₩${krwHigh.toLocaleString('ko-KR')}${' '.repeat(Math.max(0, 3 - (krwLow.toLocaleString('ko-KR').length + krwHigh.toLocaleString('ko-KR').length - 14)))} │`);
  console.log(`│ 환율            │ $1 = ₩${CONFIG.USD_KRW.toLocaleString('ko-KR').padStart(10)} │`);
  console.log('╰─────────────────┴───────────────────╯');
  
  // 변동률 경고
  if (Math.abs(changePercent) >= 4) {
    console.log(`\n⚠️ ${Math.abs(changePercent).toFixed(1)}% 변동 - 주의 필요!`);
  }
  
  // 포지션 정보
  if (position) {
    if (position.type === 'waiting') {
      console.log('\n💰 포지션: 재진입 대기 중');
      console.log(`   현금: ${position.cash}`);
      
      // 재진입 기회 분석
      if (currentPrice <= 45.00) {
        console.log(`   🟢 재진입 기회: $45 이하 (바닥 근처)`);
      } else if (currentPrice >= 50.00) {
        console.log(`   🟢 추세 전환 신호: $50 돌파`);
      } else if (currentPrice <= 48.00) {
        console.log(`   🟡 관망 영역: 아직 비쌈`);
      } else {
        console.log(`   🟡 관망 중: 진입 타이밍 대기`);
      }
    } else if (position.type === 'exited') {
      console.log('\n💰 포지션: 손절 완료');
      console.log(`   현금: ${position.cash}`);
    }
  }
  
  // 장 마감 시 다음 장 시작 시간 표시
  if (marketStatus.status === 'closed') {
    console.log(`\n⏰ 다음 장 시작: ${getNextMarketOpen()} (정규장)`);
  }
  
  console.log('\n✅ 데이터 출처: Finnhub API');
  console.log(`   조회 시각: ${new Date().toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' })}`);
}

// ============================================================================
// Main
// ============================================================================

async function main() {
  console.log('🚀 TQQQ 실시간 모니터링 (Finnhub)\n');
  
  // API 키 검증
  if (!CONFIG.FINNHUB_API_KEY) {
    console.error('❌ FINNHUB_API_KEY not found');
    console.error('   Check: ~/.openclaw/openclaw.json → env.FINNHUB_API_KEY');
    process.exit(1);
  }
  
  try {
    const data = await fetchWithRetry(CONFIG.SYMBOL, CONFIG.MAX_RETRIES);
    formatOutput(data);
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Failed after all retries');
    console.error(`   Error: ${error.message}`);
    process.exit(1);
  }
}

// ============================================================================
// Run
// ============================================================================

if (require.main === module) {
  main();
}

module.exports = { fetchFinnhubQuote, fetchWithRetry, CONFIG };
