#!/usr/bin/env python3
"""
한글 숙제 자동 교정 시스템 v5.3 (Hybrid: Claude Vision + Google Vision)
- 단어 단위 매칭 (OCR이 단어로 분리하므로)
- Y 좌표 범위로 손글씨 영역 구분

Usage:
    python3 homework-checker-v5.3.py <image_path> <errors_json>
"""

import sys
import json
import os
from pathlib import Path
from google.cloud import vision
from PIL import Image, ImageDraw, ImageFont

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = os.path.expanduser('~/.openclaw/google-vision-key.json')

def ocr_with_word_positions(image_path):
    """Google Vision DOCUMENT_TEXT_DETECTION으로 단어 좌표 추출"""
    client = vision.ImageAnnotatorClient()
    
    with open(image_path, 'rb') as f:
        content = f.read()
    
    image = vision.Image(content=content)
    response = client.document_text_detection(image=image)
    
    if response.error.message:
        raise Exception(f"Vision API Error: {response.error.message}")
    
    full_text = ""
    if response.text_annotations:
        full_text = response.text_annotations[0].description
    
    # 단어 단위 좌표
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
    
    return full_text, word_positions

def find_word_position(search_text, word_positions, min_y=0, max_y=99999):
    """특정 텍스트의 위치 찾기 (단어 단위)"""
    for wp in word_positions:
        if wp['text'] == search_text and min_y <= wp['y'] <= max_y:
            return wp
    return None

def find_adjacent_words(words_list, word_positions, min_y=0, max_y=99999):
    """인접한 단어들을 찾아서 하나의 영역으로 병합"""
    found = []
    for word in words_list:
        for wp in word_positions:
            if wp['text'] == word and min_y <= wp['y'] <= max_y:
                found.append(wp)
                break
    
    if not found:
        return None
    
    return {
        'x': min(w['x'] for w in found),
        'y': min(w['y'] for w in found),
        'x2': max(w['x2'] for w in found),
        'y2': max(w['y2'] for w in found),
    }

def mark_homework(image_path, errors, output_path=None):
    """취소선 + 빨간 텍스트 마킹"""
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    img_width = img.width
    
    try:
        font_correction = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 28)
    except:
        font_correction = ImageFont.load_default()
    
    used_text_areas = []
    
    for error in errors:
        if 'position' not in error:
            continue
            
        pos = error['position']
        x, y = pos['x'], pos['y']
        x2, y2 = pos['x2'], pos['y2']
        width = x2 - x
        height = y2 - y
        
        # 취소선 (가운데 한 줄)
        line_y = y + height // 2
        draw.line([(x - 3, line_y), (x + width + 3, line_y)], fill="red", width=3)
        
        # 정답 텍스트 위치
        text_x = x2 + 8
        text_y = y - 5
        
        text_bbox = draw.textbbox((text_x, text_y), error['corrected'], font=font_correction)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]
        
        # 경계 체크
        if text_x + text_width > img_width - 5:
            text_x = x
            text_y = y - 30
        
        # 겹침 방지
        for area in used_text_areas:
            ax, ay, ax2, ay2 = area
            if (text_x < ax2 + 3 and text_x + text_width > ax - 3 and
                text_y < ay2 + 3 and text_y + text_height > ay - 3):
                text_y = ay2 + 3
        
        used_text_areas.append((text_x, text_y, text_x + text_width, text_y + text_height))
        draw.text((text_x, text_y), error['corrected'], fill="red", font=font_correction)
    
    if output_path is None:
        base = Path(image_path).stem
        ext = Path(image_path).suffix
        parent = Path(image_path).parent
        output_path = parent / f"{base}_v5.3_corrected{ext}"
    
    img.save(output_path)
    return str(output_path)

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 homework-checker-v5.3.py <image_path> '<errors_json>'")
        sys.exit(1)
    
    image_path = sys.argv[1]
    errors_json = sys.argv[2]
    
    if not os.path.exists(image_path):
        print(f"❌ 파일 없음: {image_path}")
        sys.exit(1)
    
    errors = json.loads(errors_json)
    
    print("=" * 70)
    print("📸 한글 숙제 자동 교정 v5.3 (Hybrid)")
    print("=" * 70)
    print(f"이미지: {image_path}")
    print(f"입력된 오류: {len(errors)}개\n")
    
    # OCR
    print("🔍 Step 1: OCR...")
    full_text, word_positions = ocr_with_word_positions(image_path)
    print(f"   ✓ {len(word_positions)} 단어")
    
    # 오류 위치 매칭
    print("\n📍 Step 2: 위치 매칭...")
    errors_with_positions = []
    
    for error in errors:
        position = None
        
        # 단일 단어 검색
        if 'search' in error:
            search_text = error['search']
            min_y = error.get('min_y', 0)
            max_y = error.get('max_y', 99999)
            position = find_word_position(search_text, word_positions, min_y, max_y)
        
        # 복수 단어 검색 (인접 단어 병합)
        elif 'search_words' in error:
            words_list = error['search_words']
            min_y = error.get('min_y', 0)
            max_y = error.get('max_y', 99999)
            position = find_adjacent_words(words_list, word_positions, min_y, max_y)
        
        if position:
            error_copy = error.copy()
            error_copy['position'] = position
            errors_with_positions.append(error_copy)
            print(f"   ✓ '{error.get('original', error.get('search', ''))}' @ ({position['x']}, {position['y']})")
        else:
            print(f"   ⚠️ 못 찾음: '{error.get('original', error.get('search', ''))}'")
    
    print(f"\n   ✓ {len(errors_with_positions)}/{len(errors)}개 위치 찾음")
    
    # 마킹
    print("\n🎨 Step 3: 마킹...")
    output_path = mark_homework(image_path, errors_with_positions)
    print(f"   ✓ 저장: {output_path}")
    
    result = {
        'status': 'success',
        'version': '5.3',
        'output': output_path,
        'marked_errors': len(errors_with_positions),
        'errors': errors_with_positions,
    }
    
    print("\n--- JSON OUTPUT ---")
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
