#!/usr/bin/env node
/**
 * 관훈 예약 알림 체크
 * 관훈 가는 날 전날에만 알림 발송
 */

const fs = require('fs');
const path = require('path');

const stateFile = path.join(process.env.HOME, 'openclaw/memory/gwanhun-state.json');

// State 파일 없으면 NO_REPLY
if (!fs.existsSync(stateFile)) {
  console.log('NO_REPLY');
  process.exit(0);
}

let state;
try {
  state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
} catch (e) {
  console.log('NO_REPLY');
  process.exit(0);
}

const gwanhunDateStr = state.date; // "2026-02-06"

// 관훈일 미확정이면 NO_REPLY
if (!gwanhunDateStr || !state.confirmed) {
  console.log('NO_REPLY');
  process.exit(0);
}

// 날짜 형식 검증 (YYYY-MM-DD)
if (!/^\d{4}-\d{2}-\d{2}$/.test(gwanhunDateStr)) {
  console.log('NO_REPLY');
  process.exit(0);
}

/**
 * 한국 시간 기준 오늘 날짜 (YYYY-MM-DD)
 */
function getTodayKST() {
  const now = new Date();
  const kstOffset = 9 * 60; // KST = UTC+9
  const utcTime = now.getTime() + (now.getTimezoneOffset() * 60000);
  const kstTime = new Date(utcTime + (kstOffset * 60000));
  
  const year = kstTime.getFullYear();
  const month = String(kstTime.getMonth() + 1).padStart(2, '0');
  const day = String(kstTime.getDate()).padStart(2, '0');
  
  return `${year}-${month}-${day}`;
}

/**
 * 날짜 문자열에서 하루 빼기 (YYYY-MM-DD)
 */
function subtractDay(dateStr) {
  const [year, month, day] = dateStr.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  date.setUTCDate(date.getUTCDate() - 1);
  
  const newYear = date.getUTCFullYear();
  const newMonth = String(date.getUTCMonth() + 1).padStart(2, '0');
  const newDay = String(date.getUTCDate()).padStart(2, '0');
  
  return `${newYear}-${newMonth}-${newDay}`;
}

try {
  const todayStr = getTodayKST();
  const dayBeforeStr = subtractDay(gwanhunDateStr);

  // 오늘이 관훈일 전날이면 알림
  if (todayStr === dayBeforeStr) {
    const dayName = state.day || '내일';
    console.log(`🏢 **관훈 자리 예약하세요!**

${dayName} 관훈 출근입니다.
점심 자리 예약 잊지 마세요.

📍 관훈: 서울 종로구 인사동7길 32`);
  } else {
    console.log('NO_REPLY');
  }
} catch (e) {
  console.log('NO_REPLY');
  process.exit(0);
}
