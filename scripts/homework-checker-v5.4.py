#!/usr/bin/env python3
"""
한글 숙제 자동 교정 시스템 v5.4
- 전체 오류 마킹 (상단 + 하단)
- 교정 텍스트를 오류 위에 배치 (가독성 향상)
- 큰 폰트 + 흰색 배경 박스
"""

import sys
import json
import os
from pathlib import Path
from google.cloud import vision
from PIL import Image, ImageDraw, ImageFont

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = os.path.expanduser('~/.openclaw/google-vision-key.json')

def ocr_with_word_positions(image_path):
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

def find_adjacent_words(words_list, word_positions, min_y=0, max_y=99999):
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
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    
    try:
        font_correction = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 38)
    except:
        font_correction = ImageFont.load_default()
    
    for error in errors:
        if 'position' not in error:
            continue
            
        pos = error['position']
        x, y = pos['x'], pos['y']
        x2, y2 = pos['x2'], pos['y2']
        width = x2 - x
        height = y2 - y
        
        # 취소선 (빨간색)
        line_y = y + height // 2
        draw.line([(x - 3, line_y), (x2 + 3, line_y)], fill="red", width=4)
        
        # 교정 텍스트 위치 (오류 바로 위)
        text_bbox = draw.textbbox((0, 0), error['corrected'], font=font_correction)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]
        
        text_x = x
        text_y = y - text_height - 8
        
        if text_y < 5:
            text_y = y2 + 5
        
        # 흰색 배경 박스 (가독성)
        padding = 3
        draw.rectangle([
            text_x - padding, 
            text_y - padding, 
            text_x + text_width + padding, 
            text_y + text_height + padding
        ], fill="white", outline="red", width=1)
        
        # 빨간색 교정 텍스트
        draw.text((text_x, text_y), error['corrected'], fill="red", font=font_correction)
    
    if output_path is None:
        base = Path(image_path).stem
        ext = Path(image_path).suffix
        parent = Path(image_path).parent
        output_path = parent / f"{base}_v5.4_corrected{ext}"
    
    img.save(output_path)
    return str(output_path)

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 homework-checker-v5.4.py <image_path> '<errors_json>'")
        sys.exit(1)
    
    image_path = sys.argv[1]
    errors_json = sys.argv[2]
    
    errors = json.loads(errors_json)
    
    print("=" * 60)
    print("📸 v5.4 전체 마킹 (상단 + 하단)")
    print("=" * 60)
    
    # OCR
    word_positions = ocr_with_word_positions(image_path)
    print(f"✓ OCR: {len(word_positions)} 단어")
    
    # 위치 매칭
    errors_with_pos = []
    for error in errors:
        words = error.get('search_words', [])
        min_y = error.get('min_y', 0)
        max_y = error.get('max_y', 99999)
        
        pos = find_adjacent_words(words, word_positions, min_y, max_y)
        if pos:
            error['position'] = pos
            errors_with_pos.append(error)
            print(f"✓ {error['original']} → {error['corrected']} @ ({pos['x']}, {pos['y']})")
        else:
            print(f"✗ {error['original']} 못 찾음")
    
    # 마킹
    output_path = mark_homework(image_path, errors_with_pos)
    print(f"\n✓ 저장: {output_path}")
    print(f"✓ 마킹: {len(errors_with_pos)}개")

if __name__ == '__main__':
    main()
