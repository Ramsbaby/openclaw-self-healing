#!/usr/bin/env python3
"""
실시간 환율 조회 (USD/KRW)
Provider: exchangerate.host → open.er-api.com (페일오버)
캐시: 30분
"""

import json
import sys
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

CACHE_FILE = Path.home() / ".openclaw" / "cache" / "exchange-rate.json"
CACHE_TTL = 1800  # 30분

def load_cache():
    """캐시 파일 읽기"""
    if not CACHE_FILE.exists():
        return None
    try:
        with open(CACHE_FILE, 'r') as f:
            data = json.load(f)
        # TTL 체크
        if time.time() - data.get('timestamp', 0) < CACHE_TTL:
            return data
    except:
        pass
    return None

def save_cache(rate, source):
    """캐시 파일 저장"""
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CACHE_FILE, 'w') as f:
        json.dump({
            'rate': rate,
            'source': source,
            'timestamp': time.time()
        }, f)

def fetch_exchangerate_host():
    """Provider 1: exchangerate.host"""
    try:
        url = "https://api.exchangerate.host/latest?base=USD&symbols=KRW"
        req = Request(url, headers={
            'Accept': 'application/json',
            'User-Agent': 'OpenClaw/1.0'
        })
        with urlopen(req, timeout=7) as response:
            if response.status != 200:
                return None
            data = json.loads(response.read().decode())
            return data.get('rates', {}).get('KRW')
    except (URLError, HTTPError, Exception) as e:
        print(f"[FX] exchangerate.host error: {e}", file=sys.stderr)
        return None

def fetch_er_api():
    """Provider 2: open.er-api.com"""
    try:
        url = "https://open.er-api.com/v6/latest/USD"
        req = Request(url, headers={
            'Accept': 'application/json',
            'User-Agent': 'OpenClaw/1.0'
        })
        with urlopen(req, timeout=7) as response:
            if response.status != 200:
                return None
            data = json.loads(response.read().decode())
            if data.get('result') != 'success':
                return None
            return data.get('rates', {}).get('KRW')
    except (URLError, HTTPError, Exception) as e:
        print(f"[FX] open.er-api.com error: {e}", file=sys.stderr)
        return None

def get_rate():
    """환율 조회 (캐시 → API)"""
    # 1. 캐시 확인
    cached = load_cache()
    if cached:
        return cached['rate'], cached['source'], 'cached'
    
    # 2. API 호출 (페일오버)
    rate = fetch_exchangerate_host()
    source = 'exchangerate.host'
    if rate is None:
        rate = fetch_er_api()
        source = 'open.er-api.com'
    
    if rate is None:
        # 3. 마지막 캐시라도 있으면 사용
        if cached:
            return cached['rate'], cached['source'], 'stale-cache'
        raise Exception("환율 조회 실패: USD→KRW")
    
    # 4. 캐시 저장
    save_cache(rate, source)
    return rate, source, 'fresh'

if __name__ == '__main__':
    try:
        rate, source, status = get_rate()
        print(f"{rate:.2f}")  # 숫자만 출력 (스크립트 연동용)
        print(f"# Source: {source} ({status})", file=sys.stderr)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
