#!/usr/bin/env node
/**
 * TQQQ Polygon 실시간 모니터 (크론용)
 * 
 * Polygon REST API로 실시간 가격 조회
 * Auto-retry 포함
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
  POLYGON_API_KEY: process.env.POLYGON_API_KEY || 
    JSON.parse(fs.readFileSync(path.join(process.env.HOME, '.openclaw/openclaw.json'), 'utf8'))
      .env?.POLYGON_API_KEY,
  
  SYMBOL: 'TQQQ',
  MAX_RETRIES: 3,
  TIMEOUT: 10000, // 10초
  
  // 환율 (실시간 조회 가능하면 업그레이드)
  USD_KRW: 1465.09
};

// ============================================================================
// Polygon API 호출
// ============================================================================

function fetchPolygonQuote(symbol) {
  return new Promise((resolve, reject) => {
    const url = `https://api.polygon.io/v2/last/trade/${symbol}?apiKey=${CONFIG.POLYGON_API_KEY}`;
    
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
          
          if (json.status === 'OK' && json.results) {
            resolve(json.results);
          } else {
            reject(new Error(`Polygon API error: ${json.error || 'Unknown error'}`));
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
      const result = await fetchPolygonQuote(symbol);
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
// Format Output
// ============================================================================

function formatOutput(data) {
  const price = data.p; // Last trade price
  const timestamp = new Date(data.t / 1000000); // Nanoseconds to milliseconds
  const krwPrice = Math.round(price * CONFIG.USD_KRW);
  
  // MEMORY.md에서 포지션 정보 읽기 (실패 시 기본값)
  let position = null;
  try {
    const memoryPath = path.join(process.env.HOME, 'openclaw/MEMORY.md');
    const memoryContent = fs.readFileSync(memoryPath, 'utf8');
    
    // "현재 상황:" 섹션 파싱 (간단 정규식)
    const statusMatch = memoryContent.match(/현재 상황:\s*(.+?)(?=\n\n|\n\*\*)/s);
    if (statusMatch) {
      const statusText = statusMatch[1];
      
      // "재진입 대기" 체크
      if (statusText.includes('재진입 대기')) {
        position = {
          type: 'waiting',
          cash: '$9,000'
        };
      }
      // "손절 완료" 체크
      else if (statusText.includes('손절 완료')) {
        position = {
          type: 'exited',
          cash: '$9,000'
        };
      }
    }
  } catch (error) {
    console.error(`⚠️ Failed to read MEMORY.md: ${error.message}`);
  }
  
  // 출력
  console.log('\n📊 TQQQ 실시간 가격 (Polygon API)\n');
  console.log('╭─────────────────┬───────────────────╮');
  console.log('│ 항목            │ 값                │');
  console.log('├─────────────────┼───────────────────┤');
  console.log(`│ 현재가 (USD)    │ $${price.toFixed(2).padStart(15)} │`);
  console.log(`│ 현재가 (KRW)    │ ₩${krwPrice.toLocaleString('ko-KR').padStart(15)} │`);
  console.log(`│ 거래 시각       │ ${timestamp.toLocaleTimeString('ko-KR').padStart(15)} │`);
  console.log(`│ 거래량          │ ${data.s.toLocaleString('ko-KR').padStart(15)} │`);
  console.log(`│ 환율            │ $1 = ₩${CONFIG.USD_KRW.toLocaleString('ko-KR').padStart(10)} │`);
  console.log('╰─────────────────┴───────────────────╯');
  
  if (position) {
    if (position.type === 'waiting') {
      console.log('\n💰 포지션: 재진입 대기 중');
      console.log(`   현금: ${position.cash}`);
      console.log(`   재진입 타이밍: 고용지표 발표 후 (22:30 KST)`);
    } else if (position.type === 'exited') {
      console.log('\n💰 포지션: 손절 완료');
      console.log(`   현금: ${position.cash}`);
    }
  }
  
  console.log('\n⚠️ 데이터: Polygon 실시간 (지연 없음)');
}

// ============================================================================
// Main
// ============================================================================

async function main() {
  console.log('🚀 TQQQ Polygon 모니터링\n');
  
  // API 키 검증
  if (!CONFIG.POLYGON_API_KEY) {
    console.error('❌ POLYGON_API_KEY not found');
    console.error('   Check: ~/.openclaw/openclaw.json → env.POLYGON_API_KEY');
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

module.exports = { fetchPolygonQuote, fetchWithRetry, CONFIG };
