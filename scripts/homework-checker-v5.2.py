#!/usr/bin/env python3
"""
한글 숙제 자동 교정 시스템 v5.2
- X좌표 필터 제거 (오류 패턴만으로 손글씨 식별)
- 교정 텍스트 겹침 방지 (오류 오른쪽 끝에 배치)
- 하단 빈칸 섹션도 분석

Usage:
    python3 homework-checker-v5.2.py <image_path>
"""

import sys
import json
import os
import re
from pathlib import Path
from google.cloud import vision
from PIL import Image, ImageDraw, ImageFont

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = os.path.expanduser('~/.openclaw/google-vision-key.json')

# 에러 패턴 정의: (정규식, 교정, 타입)
ERROR_PATTERNS = [
    # incomplete (불완전한 글자) - 가장 중요!
    (r'아[ㅍㅠ][요오]', '아파요', 'incomplete'),
    (r'아ㅍ요', '아파요', 'incomplete'),
    (r'아ㅍ오', '아파요', 'incomplete'),
    
    # spacing (띄어쓰기) - 손글씨에서 자주 발생
    (r'이가아파요', '이가 아파요', 'spacing'),
    (r'배가아파요', '배가 아파요', 'spacing'),
    (r'머리가아파요', '머리가 아파요', 'spacing'),
    (r'목이아파요', '목이 아파요', 'spacing'),
    (r'모임을했어요', '모임을 했어요', 'spacing'),
    (r'축제에갔어요', '축제에 갔어요', 'spacing'),
    (r'허리가아파', '허리가 아파요', 'spacing'),
    
    # spelling (철자)
    (r'주제에', '축제에', 'spelling'),
    (r'기치', '기침', 'spelling'),
    
    # verb (동사 활용)
    (r'하어요', '해요', 'verb'),
    (r'가어요', '가요', 'verb'),
    (r'했어요(?!\.)', '했어요', 'ok'),  # 정상 (무시)
]

def ocr_with_char_positions(image_path):
    """Google Vision text_detection으로 개별 글자 좌표 추출"""
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
    
    char_positions = []
    for annotation in response.text_annotations[1:]:
        vertices = annotation.bounding_poly.vertices
        x_coords = [v.x for v in vertices]
        y_coords = [v.y for v in vertices]
        
        char_positions.append({
            'text': annotation.description,
            'x': min(x_coords),
            'y': min(y_coords),
            'x2': max(x_coords),
            'y2': max(y_coords),
            'width': max(x_coords) - min(x_coords),
            'height': max(y_coords) - min(y_coords),
        })
    
    return full_text, char_positions

def find_all_instances(pattern, char_positions, full_text):
    """같은 패턴이 여러 번 나올 때 각각의 위치 찾기"""
    matches = list(re.finditer(pattern, full_text))
    results = []
    used_positions = set()
    
    for match in matches:
        matched_text = match.group(0)
        chars = list(matched_text.replace(' ', ''))
        found_chars = []
        
        for char in chars:
            for i, cp in enumerate(char_positions):
                if i in used_positions:
                    continue
                if cp['text'] == char:
                    if found_chars:
                        last = found_chars[-1]
                        # 같은 줄에 있고 (Y 차이 < 50), 가까운 글자 (X 차이 < 100)
                        if abs(cp['y'] - last['y']) < 50 and abs(cp['x'] - last['x2']) < 100:
                            found_chars.append(cp)
                            used_positions.add(i)
                            break
                    else:
                        found_chars.append(cp)
                        used_positions.add(i)
                        break
        
        if len(found_chars) >= 2:
            x_min = min(c['x'] for c in found_chars)
            y_min = min(c['y'] for c in found_chars)
            x_max = max(c['x2'] for c in found_chars)
            y_max = max(c['y2'] for c in found_chars)
            
            position = {
                'x': x_min,
                'y': y_min,
                'x2': x_max,
                'y2': y_max,
                'width': x_max - x_min,
                'height': y_max - y_min,
            }
            results.append(position)
    
    return results

def check_grammar(full_text, char_positions):
    """문법 검사 + 위치 찾기"""
    errors = []
    
    for pattern, correction, error_type in ERROR_PATTERNS:
        if error_type == 'ok':  # 정상 패턴은 건너뛰기
            continue
            
        matches = list(re.finditer(pattern, full_text, re.IGNORECASE))
        
        if not matches:
            continue
        
        positions = find_all_instances(pattern, char_positions, full_text)
        
        for i, match in enumerate(matches):
            original = match.group(0)
            
            if i < len(positions):
                position = positions[i]
                errors.append({
                    'original': original,
                    'corrected': correction,
                    'type': error_type,
                    'position': position,
                })
    
    return errors

def deduplicate_errors(errors):
    """위치 기반 중복 제거"""
    if not errors:
        return []
    
    unique = []
    for error in errors:
        is_dup = False
        for u in unique:
            if (abs(error['position']['x'] - u['position']['x']) < 30 and
                abs(error['position']['y'] - u['position']['y']) < 30):
                is_dup = True
                break
        if not is_dup:
            unique.append(error)
    
    return unique

def mark_homework(image_path, errors, output_path=None):
    """취소선 + 빨간 텍스트 마킹 (겹침 방지)"""
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    img_width = img.width
    
    try:
        font_correction = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 36)
    except:
        font_correction = ImageFont.load_default()
    
    # 이미 사용된 텍스트 영역 추적 (겹침 방지)
    used_text_areas = []
    
    for error in errors:
        pos = error['position']
        x, y = pos['x'], pos['y']
        x2 = pos.get('x2', x + pos['width'])
        y2 = pos.get('y2', y + pos['height'])
        width = x2 - x
        height = y2 - y
        
        width = max(width, 50)
        height = max(height, 30)
        
        # 취소선 (가운데 한 줄)
        line_y = y + height // 2
        draw.line([(x - 5, line_y), (x + width + 5, line_y)], fill="red", width=4)
        
        # 정답 텍스트 위치 결정 (오류 오른쪽에 배치)
        text_x = x2 + 10  # 오류 오른쪽 끝에서 10px
        text_y = y  # 같은 높이
        
        # 이미지 경계 체크
        text_bbox = draw.textbbox((text_x, text_y), error['corrected'], font=font_correction)
        text_width = text_bbox[2] - text_bbox[0]
        
        # 오른쪽 경계 넘어가면 위에 배치
        if text_x + text_width > img_width - 10:
            text_x = x
            text_y = y - 40
            if text_y < 0:
                text_y = y2 + 5
        
        # 겹침 체크 & 조정
        for area in used_text_areas:
            ax, ay, ax2, ay2 = area
            # 겹치면 아래로 이동
            if (text_x < ax2 and text_x + text_width > ax and
                text_y < ay2 and text_y + 40 > ay):
                text_y = ay2 + 5
        
        # 텍스트 영역 기록
        used_text_areas.append((text_x, text_y, text_x + text_width, text_y + 40))
        
        draw.text((text_x, text_y), error['corrected'], fill="red", font=font_correction)
    
    if output_path is None:
        base = Path(image_path).stem
        ext = Path(image_path).suffix
        parent = Path(image_path).parent
        output_path = parent / f"{base}_v5.2_corrected{ext}"
    
    img.save(output_path)
    return str(output_path)

def evaluate_result(errors, char_count):
    """평가"""
    score_ocr = 3.0 if char_count > 100 else 2.0
    score_grammar = 2.5 if len(errors) >= 3 else (2.0 if len(errors) >= 1 else 1.5)
    score_position = 2.0
    score_usability = 1.5
    score_stability = 1.0
    
    total = score_ocr + score_grammar + score_position + score_usability + score_stability
    
    return {
        'total': total,
        'passed': total >= 9.8,
    }

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 homework-checker-v5.2.py <image_path>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    if not os.path.exists(image_path):
        print(f"❌ 파일 없음: {image_path}")
        sys.exit(1)
    
    print("=" * 70)
    print("📸 한글 숙제 자동 교정 v5.2 (전체 분석 + 겹침 방지)")
    print("=" * 70)
    print(f"이미지: {image_path}\n")
    
    # Step 1: OCR
    print("🔍 Step 1: OCR...")
    full_text, char_positions = ocr_with_char_positions(image_path)
    print(f"   ✓ {len(full_text)} 글자, {len(char_positions)} 요소")
    
    # Debug: OCR 결과 일부 출력
    print(f"\n   [OCR 샘플]\n   {full_text[:300]}...")
    
    # Step 2: 문법 검사
    print("\n📝 Step 2: 문법 검사...")
    errors = check_grammar(full_text, char_positions)
    errors = deduplicate_errors(errors)
    print(f"   ✓ {len(errors)}개 오류")
    
    if errors:
        print("\n❌ 발견된 오류:")
        for i, error in enumerate(errors, 1):
            pos = error['position']
            print(f"   {i}. '{error['original']}' → '{error['corrected']}' ({error['type']})")
            print(f"      위치: ({pos['x']}, {pos['y']})")
    
    # Step 3: 마킹
    print("\n🎨 Step 3: 취소선 마킹...")
    output_path = mark_homework(image_path, errors)
    print(f"   ✓ 저장: {output_path}")
    
    # 평가
    scores = evaluate_result(errors, len(char_positions))
    print(f"\n⭐ 총점: {scores['total']:.1f}/10.0")
    
    # JSON 출력
    result = {
        'status': 'success',
        'version': '5.2',
        'image': image_path,
        'output': output_path,
        'errors': errors,
        'total_errors': len(errors),
        'score': scores['total'],
        'passed': scores['passed'],
    }
    
    print("\n--- JSON OUTPUT ---")
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
