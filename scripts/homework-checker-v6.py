#!/usr/bin/env python3
"""
한글 숙제 자동 교정 시스템 v6 (완전 자동화)
- GPT-4o Vision: 손글씨 오류 자동 분석
- Google Vision OCR: 좌표 추출
- 자동 매칭 + 마킹

Usage:
    python3 homework-checker-v6.py <image_path>
"""

import sys
import json
import os
import base64
import re
from pathlib import Path
from openai import OpenAI
from google.cloud import vision
from PIL import Image, ImageDraw, ImageFont

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = os.path.expanduser('~/.openclaw/google-vision-key.json')

def analyze_with_gpt4v(image_path):
    """GPT-4o Vision으로 손글씨 오류 분석"""
    client = OpenAI()
    
    with open(image_path, "rb") as f:
        base64_image = base64.b64encode(f.read()).decode("utf-8")
    
    # 이미지 확장자 확인
    ext = Path(image_path).suffix.lower()
    media_type = "image/jpeg" if ext in [".jpg", ".jpeg"] else "image/png"
    
    prompt = """이 한국어 학습 숙제 이미지를 분석해주세요.

**매우 중요:**
- 인쇄된 활자체(교과서 텍스트)는 완전히 무시하세요
- 학생이 직접 쓴 **손글씨(필기체)**만 분석하세요
- 손글씨는 보통 파란색/검은색 볼펜으로 작성되어 있고, 빈칸이나 화살표(→) 옆에 있습니다

**손글씨 오류 유형:**
1. 불완전한 글자: 받침이 빠진 경우 (예: "아ㅍ요" → "아파요", "아ㅠ요" → "아파요")
2. 띄어쓰기 오류: 붙여쓴 경우 (예: "이가아파요" → "이가 아파요")
3. 활용어미 누락: "-요"가 빠진 경우 (예: "아파" → "아파요")
4. 철자 오류

**이미지 구조:**
- 상단: "가) 이/가 아파요" 옆에 화살표(→)와 손글씨 문장들
- 하단: 빈칸 채우기 문제에 학생이 쓴 손글씨 답

JSON 형식으로만 응답 (다른 설명 없이):
{
  "errors": [
    {
      "original": "학생이 쓴 손글씨 그대로",
      "corrected": "올바른 표현",
      "type": "incomplete|spacing|verb|spelling",
      "location": "top|bottom",
      "search_keywords": ["손글씨의 첫 단어"]
    }
  ]
}

location 설명:
- "top": 상단 문장 쓰기 영역 (→ 화살표 오른쪽 손글씨)
- "bottom": 하단 빈칸 채우기 영역 (문장 중간 손글씨)

search_keywords는 손글씨의 **첫 단어만** (인쇄 텍스트와 구분하기 위해):
- "목이 아ㅍ요" → ["목이"]
- "이가아파요" → ["이가아파요"] (붙여쓴 그대로)
- "모임을했어요" → ["모임을했어요"] (붙여쓴 그대로)
"""

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:{media_type};base64,{base64_image}",
                            "detail": "high"
                        }
                    }
                ]
            }
        ],
        max_tokens=2000
    )
    
    result_text = response.choices[0].message.content
    
    # JSON 추출 (```json ... ``` 형식 처리)
    json_match = re.search(r'```json\s*(.*?)\s*```', result_text, re.DOTALL)
    if json_match:
        result_text = json_match.group(1)
    
    try:
        return json.loads(result_text)
    except json.JSONDecodeError:
        # JSON 부분만 추출 시도
        json_match = re.search(r'\{.*\}', result_text, re.DOTALL)
        if json_match:
            return json.loads(json_match.group(0))
        return {"errors": [], "raw": result_text}

def ocr_with_positions(image_path):
    """Google Vision OCR로 텍스트 + 좌표 추출"""
    client = vision.ImageAnnotatorClient()
    
    with open(image_path, 'rb') as f:
        content = f.read()
    
    image = vision.Image(content=content)
    response = client.document_text_detection(image=image)
    
    if response.error.message:
        raise Exception(f"Vision API Error: {response.error.message}")
    
    word_positions = []
    for annotation in response.text_annotations[1:]:
        vertices = annotation.bounding_poly.vertices
        x_coords = [v.x for v in vertices]
        y_coords = [v.y for v in vertices]
        word_positions.append({
            'text': annotation.description,
            'x': min(x_coords),
            'y': min(y_coords),
            'x2': max(x_coords),
            'y2': max(y_coords),
        })
    
    return word_positions

def find_error_position(error, word_positions):
    """오류의 OCR 좌표 찾기 (location 기반 필터링)"""
    keywords = error.get('search_keywords', [])
    location = error.get('location', '')
    
    # location 기반 필터링
    filtered_positions = word_positions
    if location == 'top':
        # 상단 손글씨: X > 1500 (→ 화살표 오른쪽)
        filtered_positions = [wp for wp in word_positions if wp['x'] > 1500]
    elif location == 'bottom':
        # 하단 손글씨: Y > 2500 (빈칸 채우기 영역)
        filtered_positions = [wp for wp in word_positions if wp['y'] > 2500]
    
    for kw in keywords:
        for wp in filtered_positions:
            if kw in wp['text'] or wp['text'] in kw:
                return wp
    
    # 키워드로 못 찾으면 original에서 단어 추출
    original = error.get('original', '').replace(' ', '')
    
    for wp in filtered_positions:
        if wp['text'] in original or original in wp['text']:
            return wp
    
    # 필터링 없이 전체에서 찾기 (fallback)
    for kw in keywords:
        for wp in word_positions:
            if kw in wp['text'] or wp['text'] in kw:
                return wp
    
    return None

def mark_homework(image_path, errors, output_path=None):
    """마킹"""
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    
    # 이미지 크기에 따라 폰트 크기 조정
    img_height = img.height
    font_size = max(30, img_height // 100)
    
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", font_size)
    except:
        font = ImageFont.load_default()
    
    for error in errors:
        if 'position' not in error:
            continue
            
        pos = error['position']
        x, y = pos['x'], pos['y']
        x2, y2 = pos['x2'], pos['y2']
        height = y2 - y
        
        # 취소선
        line_y = y + height // 2
        draw.line([(x - 3, line_y), (x2 + 3, line_y)], fill="red", width=max(3, font_size // 10))
        
        # 교정 텍스트
        text_bbox = draw.textbbox((0, 0), error['corrected'], font=font)
        text_w = text_bbox[2] - text_bbox[0]
        text_h = text_bbox[3] - text_bbox[1]
        
        text_x = x
        text_y = y - text_h - 8
        if text_y < 5:
            text_y = y2 + 5
        
        # 흰색 배경
        pad = 3
        draw.rectangle([text_x - pad, text_y - pad, text_x + text_w + pad, text_y + text_h + pad], 
                       fill="white", outline="red", width=1)
        draw.text((text_x, text_y), error['corrected'], fill="red", font=font)
    
    if output_path is None:
        base = Path(image_path).stem
        ext = Path(image_path).suffix
        parent = Path(image_path).parent
        output_path = parent / f"{base}_v6_corrected{ext}"
    
    img.save(output_path)
    return str(output_path)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 homework-checker-v6.py <image_path>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    if not os.path.exists(image_path):
        print(f"❌ 파일 없음: {image_path}")
        sys.exit(1)
    
    print("=" * 60)
    print("📸 한글 숙제 자동 교정 v6 (완전 자동화)")
    print("=" * 60)
    print(f"이미지: {image_path}\n")
    
    # Step 1: GPT-4o Vision 분석
    print("🤖 Step 1: GPT-4o Vision 분석...")
    analysis = analyze_with_gpt4v(image_path)
    errors = analysis.get('errors', [])
    print(f"   ✓ {len(errors)}개 오류 감지")
    
    if errors:
        for e in errors:
            print(f"   - {e.get('original', '?')} → {e.get('corrected', '?')} ({e.get('type', '?')})")
    
    # Step 2: Google Vision OCR
    print("\n🔍 Step 2: Google Vision OCR...")
    word_positions = ocr_with_positions(image_path)
    print(f"   ✓ {len(word_positions)} 단어")
    
    # Step 3: 위치 매칭
    print("\n📍 Step 3: 위치 매칭...")
    errors_with_pos = []
    for error in errors:
        pos = find_error_position(error, word_positions)
        if pos:
            error['position'] = pos
            errors_with_pos.append(error)
            print(f"   ✓ {error.get('original', '?')} @ ({pos['x']}, {pos['y']})")
        else:
            print(f"   ✗ {error.get('original', '?')} 위치 못 찾음")
    
    # Step 4: 마킹
    print("\n🎨 Step 4: 마킹...")
    output_path = mark_homework(image_path, errors_with_pos)
    print(f"   ✓ 저장: {output_path}")
    
    # 결과
    print(f"\n✅ 완료: {len(errors_with_pos)}개 오류 마킹")
    
    result = {
        'status': 'success',
        'version': '6.0',
        'output': output_path,
        'total_errors': len(errors),
        'marked_errors': len(errors_with_pos),
        'errors': errors_with_pos,
    }
    
    print("\n--- JSON OUTPUT ---")
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
