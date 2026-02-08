#!/usr/bin/env python3
"""
TQQQ Yahoo Finance 모니터 (크론용)
애프터마켓 포함 실시간 가격
"""

import yfinance as yf
import json
import os
from datetime import datetime
import pytz

# Configuration
SYMBOL = 'TQQQ'
USD_KRW = 1465.09
MEMORY_PATH = os.path.expanduser('~/openclaw/MEMORY.md')

def get_market_status():
    """장 상태 판단"""
    ny_tz = pytz.timezone('America/New_York')
    now = datetime.now(ny_tz)
    hour = now.hour
    minute = now.minute
    day = now.weekday()  # 0=월, 6=일
    
    # 주말
    if day >= 5:
        return {'status': 'closed', 'label': '⏸️ 주말 휴장 - 마지막 종가'}
    
    total_minutes = hour * 60 + minute
    
    # 정규장: 09:30 - 16:00 EST
    if 9 * 60 + 30 <= total_minutes < 16 * 60:
        return {'status': 'market', 'label': '🟢 정규장 실시간'}
    
    # 애프터마켓: 16:00 - 20:00 EST
    if 16 * 60 <= total_minutes < 20 * 60:
        return {'status': 'aftermarket', 'label': '🟡 애프터마켓'}
    
    # 프리마켓: 04:00 - 09:30 EST
    if 4 * 60 <= total_minutes < 9 * 60 + 30:
        return {'status': 'premarket', 'label': '🟠 프리마켓'}
    
    # 장 마감
    return {'status': 'closed', 'label': '⏸️ 장 마감 - 마지막 종가'}

def get_next_market_open():
    """다음 장 시작 시간"""
    kst_tz = pytz.timezone('Asia/Seoul')
    now = datetime.now(kst_tz)
    
    # 다음 정규장: 23:30 KST
    next_open = now.replace(hour=23, minute=30, second=0, microsecond=0)
    
    # 이미 지났으면 내일
    if now.hour >= 23 and now.minute >= 30:
        next_open = next_open.replace(day=now.day + 1)
    
    # 주말이면 다음 월요일
    day = next_open.weekday()
    if day == 6:  # 일요일 → 월요일
        next_open = next_open.replace(day=next_open.day + 1)
    if day == 5:  # 토요일 → 월요일
        next_open = next_open.replace(day=next_open.day + 2)
    
    return next_open.strftime('%m월 %d일 %p %I:%M')

def get_position_from_memory():
    """MEMORY.md에서 포지션 정보 읽기"""
    try:
        with open(MEMORY_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
            
        if '재진입 대기' in content:
            return {'type': 'waiting', 'cash': '$9,000'}
        elif '손절 완료' in content:
            return {'type': 'exited', 'cash': '$9,000'}
    except Exception as e:
        print(f'⚠️ Failed to read MEMORY.md: {e}')
    
    return None

def main():
    print('🚀 TQQQ Yahoo Finance 모니터링\n')
    
    try:
        # Fetch data
        ticker = yf.Ticker(SYMBOL)
        info = ticker.info
        
        # Prices
        regular_price = info.get('regularMarketPrice', 0)
        post_price = info.get('postMarketPrice')
        pre_price = info.get('preMarketPrice')
        prev_close = info.get('previousClose', regular_price)
        
        # Market status
        market_status = get_market_status()
        
        # Choose current price (애프터마켓 종료 후에도 postMarketPrice 우선)
        if post_price:
            current_price = post_price
            market_status['label'] = '🟡 애프터마켓 최종가'
        elif pre_price:
            current_price = pre_price
            market_status['label'] = '🟠 프리마켓 최종가'
        else:
            current_price = regular_price
        
        # Calculate
        krw_price = round(current_price * USD_KRW)
        change = current_price - prev_close
        change_percent = (change / prev_close * 100) if prev_close else 0
        
        # Day range
        day_high = info.get('dayHigh', current_price)
        day_low = info.get('dayLow', current_price)
        krw_high = round(day_high * USD_KRW)
        krw_low = round(day_low * USD_KRW)
        
        # Position
        position = get_position_from_memory()
        
        # Output
        print(f'📊 TQQQ 스냅샷 (Yahoo Finance)\n')
        print(f'{market_status["label"]}\n')
        print('╭─────────────────┬───────────────────╮')
        print('│ 항목            │ 값                │')
        print('├─────────────────┼───────────────────┤')
        print(f'│ 현재가 (USD)    │ ${current_price:>15.2f} │')
        print(f'│ 현재가 (KRW)    │ ₩{krw_price:>15,} │')
        print(f'│ 전일 종가       │ ${prev_close:>15.2f} │')
        
        change_icon = '▲' if change >= 0 else '▼'
        print(f'│ 변동 (전일比)   │ {change_icon} ${abs(change):.2f} ({change_percent:+.2f}%)  │')
        
        print(f'│ 일중 범위       │ ${day_low:.2f} ~ ${day_high:.2f}  │')
        print(f'│ 일중 범위 (KRW) │ ₩{krw_low:,} ~ ₩{krw_high:,}  │')
        print(f'│ 환율            │ $1 = ₩{USD_KRW:>10,} │')
        print('╰─────────────────┴───────────────────╯')
        
        # Warning
        if abs(change_percent) >= 4:
            print(f'\n⚠️ {abs(change_percent):.1f}% 변동 - 주의 필요!')
        
        # Position
        if position:
            if position['type'] == 'waiting':
                print(f'\n💰 포지션: 재진입 대기 중')
                print(f'   현금: {position["cash"]}')
                
                if current_price <= 45.00:
                    print(f'   🟢 재진입 기회: $45 이하 (바닥 근처)')
                elif current_price >= 50.00:
                    print(f'   🟢 추세 전환 신호: $50 돌파')
                elif current_price <= 48.00:
                    print(f'   🟡 관망 영역: 아직 비쌈')
                else:
                    print(f'   🟡 관망 중: 진입 타이밍 대기')
            
            elif position['type'] == 'exited':
                print(f'\n💰 포지션: 손절 완료')
                print(f'   현금: {position["cash"]}')
        
        # Next market open
        if market_status['status'] == 'closed':
            print(f'\n⏰ 다음 장 시작: {get_next_market_open()} (정규장)')
        
        # Timestamp
        kst = datetime.now(pytz.timezone('Asia/Seoul'))
        print(f'\n✅ 데이터 출처: Yahoo Finance (애프터마켓 포함)')
        print(f'   조회 시각: {kst.strftime("%Y. %m. %d. %p %I:%M:%S")}')
        
    except Exception as e:
        print(f'❌ Error: {e}')
        exit(1)

if __name__ == '__main__':
    main()
