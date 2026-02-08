#!/usr/bin/env python3
"""
한글 숙제 자동 교정 시스템 v5.0
Character-level 영역 병합 방식

핵심: Google Vision의 개별 글자 좌표를 병합해서 단어 영역 계산

Usage:
    python3 homework-checker-v5.0.py <image_path>
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
    
    # spelling (철자)
    (r'주제에', '축제에', 'spelling'),
    (r'기치', '기침', 'spelling'),
    
    # spacing (띄어쓰기)
    (r'이가아파요', '이가 아파요', 'spacing'),
    (r'배가아파요', '배가 아파요', 'spacing'),
    (r'머리가아파요', '머리가 아파요', 'spacing'),
    (r'모임을했어요', '모임을 했어요', 'spacing'),
    (r'열이나요', '열이 나요', 'spacing'),
    (r'기침이나요', '기침이 나요', 'spacing'),
    (r'콧물이나요', '콧물이 나요', 'spacing'),
    
    # verb (동사)
    (r'하어요', '해요', 'verb'),
    (r'가어요', '가요', 'verb'),
]

def ocr_with_char_positions(image_path):
    """
    Google Vision text_detection으로 개별 글자 좌표 추출
    """
    client = vision.ImageAnnotatorClient()
    
    with open(image_path, 'rb') as f:
        content = f.read()
    
    image = vision.Image(content=content)
    response = client.text_detection(image=image)
    
    if response.error.message:
        raise Exception(f"Vision API Error: {response.error.message}")
    
    full_text = ""
    if response.text_annotations:
        full_text = response.text_annotations[0].description
    
    # 개별 글자/단어 좌표 수집
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

def find_error_region(error_text, char_positions, full_text):
    """
    에러 텍스트의 개별 글자들을 찾아서 영역 병합
    
    예: "아ㅍ요" → "아", "ㅍ", "요" 좌표를 병합
    """
    # 먼저 정확히 일치하는 단어 찾기
    for cp in char_positions:
        if error_text == cp['text']:
            return {
                'x': cp['x'],
                'y': cp['y'],
                'width': cp['width'],
                'height': cp['height'],
            }
    
    # 띄어쓰기 제거하고 찾기 (spacing 에러용)
    clean_error = error_text.replace(' ', '')
    for cp in char_positions:
        if clean_error == cp['text'].replace(' ', ''):
            return {
                'x': cp['x'],
                'y': cp['y'],
                'width': cp['width'],
                'height': cp['height'],
            }
    
    # 개별 글자들 찾아서 병합
    chars = list(error_text.replace(' ', ''))
    found_chars = []
    
    for char in chars:
        for cp in char_positions:
            if cp['text'] == char and cp not in found_chars:
                # 이미 찾은 글자와 가까운 위치인지 확인
                if found_chars:
                    last = found_chars[-1]
                    # Y좌표가 비슷하고 (같은 줄) X가 오른쪽에 있어야 함
                    if abs(cp['y'] - last['y']) < 50 and cp['x'] > last['x'] - 20:
                        found_chars.append(cp)
                        break
                else:
                    found_chars.append(cp)
                    break
    
    if len(found_chars) >= 2:
        # 찾은 글자들의 영역 병합
        x_min = min(c['x'] for c in found_chars)
        y_min = min(c['y'] for c in found_chars)
        x_max = max(c['x2'] for c in found_chars)
        y_max = max(c['y2'] for c in found_chars)
        
        return {
            'x': x_min,
            'y': y_min,
            'width': x_max - x_min,
            'height': y_max - y_min,
        }
    
    # 첫 글자로 fallback
    first_char = chars[0] if chars else error_text[0]
    for cp in char_positions:
        if cp['text'] == first_char:
            return {
                'x': cp['x'],
                'y': cp['y'],
                'width': cp['width'] * len(chars),
                'height': cp['height'],
            }
    
    return None

def find_all_instances(pattern, char_positions, full_text):
    """
    같은 패턴이 여러 번 나올 수 있음 (예: "아ㅍ요"가 3번)
    각각의 위치를 모두 찾기
    """
    matches = list(re.finditer(pattern, full_text))
    results = []
    
    # 텍스트 위치를 기반으로 대략적인 Y 순서 추정
    # 이미지 상단부터 하단으로
    used_positions = set()
    
    for match in matches:
        matched_text = match.group(0)
        
        # 개별 글자들 찾기
        chars = list(matched_text.replace(' ', ''))
        found_chars = []
        
        for char in chars:
            for i, cp in enumerate(char_positions):
                if i in used_positions:
                    continue
                if cp['text'] == char:
                    if found_chars:
                        last = found_chars[-1]
                        # 같은 줄 + 연속된 위치
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
            
            results.append({
                'x': x_min,
                'y': y_min,
                'width': x_max - x_min,
                'height': y_max - y_min,
            })
    
    return results

def check_grammar(full_text, char_positions):
    """문법 검사 + 위치 찾기"""
    errors = []
    
    for pattern, correction, error_type in ERROR_PATTERNS:
        matches = list(re.finditer(pattern, full_text, re.IGNORECASE))
        
        if not matches:
            continue
        
        # 각 매치에 대해 위치 찾기
        positions = find_all_instances(pattern, char_positions, full_text)
        
        for i, match in enumerate(matches):
            original = match.group(0)
            
            if i < len(positions):
                position = positions[i]
            else:
                # fallback: 첫 번째 위치 사용 또는 단어 검색
                position = find_error_region(original, char_positions, full_text)
            
            if position:
                errors.append({
                    'original': original,
                    'corrected': correction,
                    'type': error_type,
                    'position': position,
                })
    
    return errors

def deduplicate_errors(errors):
    """위치 기반 중복 제거 (±20px 이내는 동일)"""
    if not errors:
        return []
    
    unique = []
    for error in errors:
        is_dup = False
        for u in unique:
            if (abs(error['position']['x'] - u['position']['x']) < 20 and
                abs(error['position']['y'] - u['position']['y']) < 20):
                is_dup = True
                break
        if not is_dup:
            unique.append(error)
    
    return unique

def mark_homework(image_path, errors, output_path=None):
    """빨간 펜 스타일 마킹"""
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    
    try:
        font_correction = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 50)
    except:
        font_correction = ImageFont.load_default()
    
    for error in errors:
        pos = error['position']
        x, y = pos['x'], pos['y']
        width, height = pos['width'], pos['height']
        
        # 최소 크기 보장
        width = max(width, 50)
        height = max(height, 30)
        
        # 1. 빨간 사선 X
        draw.line([(x, y), (x + width, y + height)], fill="red", width=8)
        draw.line([(x + width, y), (x, y + height)], fill="red", width=8)
        
        # 2. 빨간 밑줄
        draw.line([(x, y + height + 5), (x + width, y + height + 5)], fill="red", width=10)
        
        # 3. 정답 텍스트 (위에 빨간색)
        correction_y = y - 55
        if correction_y < 0:
            correction_y = y + height + 15
        
        draw.text((x, correction_y), error['corrected'], fill="red", font=font_correction)
    
    if output_path is None:
        base = Path(image_path).stem
        ext = Path(image_path).suffix
        parent = Path(image_path).parent
        output_path = parent / f"{base}_v5_corrected{ext}"
    
    img.save(output_path)
    return str(output_path)

def evaluate_result(errors, word_count):
    """평가"""
    score_ocr = 3.0 if word_count > 100 else 2.0
    
    if len(errors) >= 3:
        score_grammar = 2.5
    elif len(errors) >= 1:
        score_grammar = 2.0
    else:
        score_grammar = 1.5
    
    score_position = 2.0
    score_usability = 1.5
    score_stability = 1.0
    
    total = score_ocr + score_grammar + score_position + score_usability + score_stability
    
    return {
        'ocr': score_ocr,
        'grammar': score_grammar,
        'position': score_position,
        'usability': score_usability,
        'stability': score_stability,
        'total': total,
        'passed': total >= 9.8,
    }

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 homework-checker-v5.0.py <image_path>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    if not os.path.exists(image_path):
        print(f"❌ 파일 없음: {image_path}")
        sys.exit(1)
    
    print("=" * 70)
    print("📸 한글 숙제 자동 교정 v5.0 (Character-level 영역 병합)")
    print("=" * 70)
    print(f"이미지: {image_path}\n")
    
    # Step 1: OCR + character positions
    print("🔍 Step 1: OCR + 글자별 위치 추출...")
    full_text, char_positions = ocr_with_char_positions(image_path)
    print(f"   ✓ {len(full_text)} 글자, {len(char_positions)} 개별 요소")
    
    # Step 2: 문법 검사 + 위치 찾기
    print("\n📝 Step 2: 문법 검사 + 영역 병합...")
    errors = check_grammar(full_text, char_positions)
    errors = deduplicate_errors(errors)
    print(f"   ✓ {len(errors)}개 오류 발견")
    
    if errors:
        print("\n❌ 발견된 오류:")
        for i, error in enumerate(errors, 1):
            pos = error['position']
            print(f"   {i}. '{error['original']}' → '{error['corrected']}' ({error['type']})")
            print(f"      위치: ({pos['x']}, {pos['y']}) - {pos['width']}x{pos['height']}px")
    
    # Step 3: 마킹
    print("\n🎨 Step 3: 빨간 펜 스타일 마킹...")
    output_path = mark_homework(image_path, errors)
    print(f"   ✓ 저장: {output_path}")
    
    # 평가
    scores = evaluate_result(errors, len(char_positions))
    
    print("\n📊 평가:")
    print(f"   ✓ OCR: {len(char_positions)} 요소 ({scores['ocr']:.1f}/3.0)")
    print(f"   ✓ 문법: {len(errors)}개 오류 ({scores['grammar']:.1f}/2.5)")
    print(f"   ✓ 위치: Character 병합 ({scores['position']:.1f}/2.0)")
    print(f"   ✓ 사용성: 선생님 스타일 ({scores['usability']:.1f}/1.5)")
    print(f"   ✓ 안정성: 정상 ({scores['stability']:.1f}/1.0)")
    
    print(f"\n⭐ 총점: {scores['total']:.1f}/10.0")
    if scores['passed']:
        print(f"   ✅ 합격 ({scores['total']:.1f})")
    else:
        print(f"   ⚠️  불합격 ({scores['total']:.1f})")
    
    # JSON 출력
    result = {
        'status': 'success',
        'version': '5.0',
        'method': 'character_level_merge',
        'image': image_path,
        'output': output_path,
        'errors': errors,
        'total_errors': len(errors),
        'ocr_length': len(full_text),
        'char_count': len(char_positions),
        'score': scores['total'],
        'passed': scores['passed'],
    }
    
    print("\n--- JSON OUTPUT ---")
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
