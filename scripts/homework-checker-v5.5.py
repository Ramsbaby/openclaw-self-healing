#!/usr/bin/env python3
"""
한글 숙제 자동 교정 시스템 v5.5
- 인쇄 텍스트 제외 (X 좌표 필터)
- 손글씨만 마킹
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

def find_word(word, word_positions, min_x=0, max_x=99999, min_y=0, max_y=99999):
    """단어 찾기 (X, Y 좌표 범위 필터)"""
    for wp in word_positions:
        if wp['text'] == word:
            if min_x <= wp['x'] <= max_x and min_y <= wp['y'] <= max_y:
                return wp
    return None

def find_adjacent_words(words_list, word_positions, min_x=0, max_x=99999, min_y=0, max_y=99999):
    """인접 단어들 찾아서 병합"""
    found = []
    for word in words_list:
        wp = find_word(word, word_positions, min_x, max_x, min_y, max_y)
        if wp:
            found.append(wp)
    
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
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 36)
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
        draw.line([(x - 3, line_y), (x2 + 3, line_y)], fill="red", width=4)
        
        # 교정 텍스트 (오류 위)
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
        output_path = parent / f"{base}_v5.5_corrected{ext}"
    
    img.save(output_path)
    return str(output_path)

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 homework-checker-v5.5.py <image_path> '<errors_json>'")
        sys.exit(1)
    
    image_path = sys.argv[1]
    errors_json = sys.argv[2]
    errors = json.loads(errors_json)
    
    print("=" * 60)
    print("📸 v5.5 손글씨만 마킹 (인쇄 텍스트 제외)")
    print("=" * 60)
    
    word_positions = ocr_with_word_positions(image_path)
    print(f"✓ OCR: {len(word_positions)} 단어")
    
    errors_with_pos = []
    for error in errors:
        words = error.get('search_words', [])
        min_x = error.get('min_x', 0)
        max_x = error.get('max_x', 99999)
        min_y = error.get('min_y', 0)
        max_y = error.get('max_y', 99999)
        
        pos = find_adjacent_words(words, word_positions, min_x, max_x, min_y, max_y)
        if pos:
            error['position'] = pos
            errors_with_pos.append(error)
            print(f"✓ {error['original']} @ X={pos['x']}, Y={pos['y']}")
        else:
            print(f"✗ {error['original']} 못 찾음")
    
    output_path = mark_homework(image_path, errors_with_pos)
    print(f"\n✓ 저장: {output_path}")
    print(f"✓ 마킹: {len(errors_with_pos)}개")

if __name__ == '__main__':
    main()
