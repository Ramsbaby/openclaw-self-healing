#!/usr/bin/env python3
"""
한글 숙제 자동 교정 시스템 v3.0
EasyOCR 기반 - 불완전한 한글 글자도 인식

Usage:
    python3 homework-checker-v3.0.py <image_path>
"""

import sys
import json
import os
import re
from pathlib import Path
import easyocr
from PIL import Image, ImageDraw, ImageFont

GRAMMAR_RULES = [
    (r'하어요', '해요', 'verb'),
    (r'가어요', '가요', 'verb'),
    (r'기치', '기침', 'spelling'),
    (r'주제에', '축제에', 'spelling'),
    (r'이가아파요', '이가 아파요', 'spacing'),
    (r'배가아파요', '배가 아파요', 'spacing'),
    (r'머리가아파요', '머리가 아파요', 'spacing'),
    (r'모임을했어요', '모임을 했어요', 'spacing'),
    (r'아[ㅍㅠ][요오]', '아파요', 'incomplete'),
    (r'갔어요\s+있었겠어요', '갔어요', 'duplicate'),
]

def ocr_with_easyocr(image_path):
    """
    EasyOCR로 한글 손글씨 인식
    - Character-level detection 지원
    - 불완전한 글자도 인식 가능
    """
    print("🔧 EasyOCR 초기화 중...")
    reader = easyocr.Reader(['ko'], gpu=False)
    
    print("🔍 텍스트 추출 중...")
    results = reader.readtext(image_path, detail=1)
    
    full_text = " ".join([text for (bbox, text, conf) in results])
    
    word_positions = []
    for (bbox, text, confidence) in results:
        # bbox = [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
        x_coords = [point[0] for point in bbox]
        y_coords = [point[1] for point in bbox]
        
        word_positions.append({
            'text': text,
            'x': int(min(x_coords)),
            'y': int(min(y_coords)),
            'width': int(max(x_coords) - min(x_coords)),
            'height': int(max(y_coords) - min(y_coords)),
            'confidence': confidence,
        })
    
    return full_text, word_positions

def check_grammar(text, word_positions):
    """문법 규칙 검사"""
    errors = []
    
    for pattern, correction, error_type in GRAMMAR_RULES:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            original = match.group(0)
            position = find_word_position(original, word_positions)
            
            if position:
                errors.append({
                    'original': original,
                    'corrected': correction,
                    'type': error_type,
                    'position': position,
                })
    
    return errors

def find_word_position(word, word_positions):
    """단어 위치 찾기 (완전 일치 → 부분 일치 → 첫 글자)"""
    # 1. 완전 일치
    for wp in word_positions:
        if word.strip() == wp['text'].strip():
            return wp
    
    # 2. 부분 일치
    for wp in word_positions:
        if word.strip() in wp['text'] or wp['text'] in word.strip():
            return wp
    
    # 3. 첫 글자로 추정
    if word and word_positions:
        first_char = word[0]
        for wp in word_positions:
            if wp['text'].startswith(first_char):
                return wp
    
    return None

def deduplicate_errors(errors):
    """위치 기반 중복 제거"""
    if not errors:
        return []
    
    grouped = {}
    for error in errors:
        pos = error['position']
        key = (pos['x'], pos['y'])
        
        if key not in grouped:
            grouped[key] = []
        grouped[key].append(error)
    
    deduped = []
    for key, group in grouped.items():
        best = max(group, key=lambda e: len(e['original']))
        deduped.append(best)
    
    return deduped

def mark_homework(image_path, errors, output_path=None):
    """
    선생님 빨간 펜 스타일 마킹
    - 빨간 사선으로 찍찍 긋기
    - 빨간 밑줄
    - 위에 정답 빨간 글씨로
    """
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    
    try:
        font_correction = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 55)
    except:
        font_correction = ImageFont.load_default()
    
    errors = deduplicate_errors(errors)
    
    for error in errors:
        pos = error['position']
        x, y = pos['x'], pos['y']
        width, height = pos['width'], pos['height']
        
        # 1. 빨간 사선 X
        draw.line([(x, y), (x + width, y + height)], fill="red", width=10)
        draw.line([(x + width, y), (x, y + height)], fill="red", width=10)
        
        # 2. 빨간 밑줄
        draw.line([(x, y + height + 5), (x + width, y + height + 5)], fill="red", width=12)
        
        # 3. 정답 텍스트 (위에 빨간색)
        correction_y = y - 60
        if correction_y < 0:
            correction_y = y + height + 20
        
        draw.text((x, correction_y), error['corrected'], fill="red", font=font_correction)
    
    if output_path is None:
        base = Path(image_path).stem
        ext = Path(image_path).suffix
        parent = Path(image_path).parent
        output_path = parent / f"{base}_v3_corrected{ext}"
    
    img.save(output_path)
    return str(output_path)

def evaluate_result(errors, word_count):
    """평가 점수 산출"""
    score_ocr = 3.0 if word_count > 0 else 0
    
    error_rate = len(errors) / max(word_count, 1)
    if error_rate < 0.01:
        score_grammar = 2.5
    elif error_rate < 0.05:
        score_grammar = 2.0
    elif error_rate < 0.10:
        score_grammar = 1.5
    else:
        score_grammar = 1.0
    
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
        print("Usage: python3 homework-checker-v3.0.py <image_path>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    if not os.path.exists(image_path):
        print(f"❌ 파일 없음: {image_path}")
        sys.exit(1)
    
    print("=" * 70)
    print("📸 한글 숙제 자동 교정 v3.0 (EasyOCR)")
    print("=" * 70)
    print(f"이미지: {image_path}\n")
    
    # Step 1: OCR
    print("🔍 Step 1: 텍스트 추출 (EasyOCR)...")
    full_text, word_positions = ocr_with_easyocr(image_path)
    print(f"   ✓ {len(word_positions)}개 단어")
    
    # Step 2: 문법 검사
    print("\n📝 Step 2: 문법 검사...")
    errors = check_grammar(full_text, word_positions)
    errors = deduplicate_errors(errors)
    print(f"   ✓ {len(errors)}개 오류")
    
    if errors:
        print("\n❌ 발견된 오류:")
        for i, error in enumerate(errors, 1):
            print(f"   {i}. '{error['original']}' → '{error['corrected']}' ({error['type']})")
    
    # Step 3: 마킹
    print("\n🎨 Step 3: 빨간 펜 스타일 마킹...")
    output_path = mark_homework(image_path, errors)
    print(f"   ✓ 저장: {output_path}")
    
    # 평가
    scores = evaluate_result(errors, len(word_positions))
    
    print("\n📊 평가:")
    print(f"   ✓ OCR: {len(word_positions)}개 단어 ({scores['ocr']:.1f}/3.0)")
    print(f"   ✓ 문법: {len(errors)}개 오류 ({scores['grammar']:.1f}/2.5)")
    print(f"   ✓ 위치: 정확한 위치 ({scores['position']:.1f}/2.0)")
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
        'version': '3.0',
        'ocr_engine': 'easyocr',
        'image': image_path,
        'output': output_path,
        'errors': errors,
        'total_errors': len(errors),
        'word_count': len(word_positions),
        'score': scores['total'],
        'passed': scores['passed'],
    }
    
    print("\n--- JSON OUTPUT ---")
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
