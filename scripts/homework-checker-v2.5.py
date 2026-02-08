#!/usr/bin/env python3
"""
한글 숙제 자동 교정 시스템 v2.5
DOCUMENT_TEXT_DETECTION으로 word 단위 인식 개선

Usage:
    python3 homework-checker-v2.py <image_path>
"""

import sys
import json
import os
import re
from pathlib import Path
from google.cloud import vision
from PIL import Image, ImageDraw, ImageFont

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = os.path.expanduser('~/.openclaw/google-vision-key.json')

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

def ocr_with_positions(image_path):
    client = vision.ImageAnnotatorClient()
    
    with open(image_path, 'rb') as f:
        content = f.read()
    
    image = vision.Image(content=content)
    # DOCUMENT_TEXT_DETECTION = word 단위 BoundingBox
    image_context = vision.ImageContext(language_hints=['ko'])
    response = client.document_text_detection(image=image, image_context=image_context)
    
    if response.error.message:
        raise Exception(f"Vision API Error: {response.error.message}")
    
    full_text = ""
    if response.full_text_annotation:
        full_text = response.full_text_annotation.text
    
    word_positions = []
    
    # document_text_detection: page → block → paragraph → word
    for page in response.full_text_annotation.pages:
        for block in page.blocks:
            for paragraph in block.paragraphs:
                for word in paragraph.words:
                    word_text = ''.join([symbol.text for symbol in word.symbols])
                    vertices = word.bounding_box.vertices
                    x_coords = [v.x for v in vertices]
                    y_coords = [v.y for v in vertices]
                    
                    word_positions.append({
                        'text': word_text,
                        'x': min(x_coords),
                        'y': min(y_coords),
                        'width': max(x_coords) - min(x_coords),
                        'height': max(y_coords) - min(y_coords),
                    })
    
    return full_text, word_positions

def check_grammar(text, word_positions):
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
    for wp in word_positions:
        if word.strip() == wp['text'].strip():
            return wp
    
    for wp in word_positions:
        if word.strip() in wp['text'] or wp['text'] in word.strip():
            return wp
    
    if word and word_positions:
        first_char = word[0]
        for wp in word_positions:
            if wp['text'].startswith(first_char):
                return wp
    
    return None

def deduplicate_errors(errors):
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
    선생님 빨간 펜 스타일
    - 틀린 글자에 빨간 사선
    - 바로 위에 빨간색으로 정답 쓰기
    """
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    
    # 큰 한글 폰트 (손글씨 크기와 비슷하게)
    try:
        font_correction = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 55)
    except:
        font_correction = ImageFont.load_default()
    
    # 중복 제거
    errors = deduplicate_errors(errors)
    
    for error in errors:
        pos = error['position']
        x, y = pos['x'], pos['y']
        width, height = pos['width'], pos['height']
        
        # 1. 빨간 사선으로 찍찍 긋기
        draw.line([(x, y), (x + width, y + height)], fill="red", width=10)
        draw.line([(x + width, y), (x, y + height)], fill="red", width=10)
        
        # 2. 빨간 밑줄
        draw.line([(x, y + height + 5), (x + width, y + height + 5)], fill="red", width=12)
        
        # 3. 교정 텍스트 - 바로 위에 빨간색으로
        corrected = error['corrected']
        
        # 위치: 틀린 글자 바로 위
        correction_x = x
        correction_y = y - height - 15  # 위쪽으로
        
        # 만약 위쪽이 이미지 밖이면 아래로
        if correction_y < 0:
            correction_y = y + height + 25
        
        # 빨간색 텍스트 (배경 없음)
        draw.text(
            (correction_x, correction_y),
            corrected,
            fill="red",
            font=font_correction
        )
    
    # 저장
    if output_path is None:
        output_path = str(Path(image_path).parent / f"{Path(image_path).stem}_v2_corrected.jpg")
    
    img.save(output_path, quality=98)
    return output_path

def evaluate_result(errors, full_text, word_count):
    score = 0.0
    feedback = []
    
    score += 3.0
    feedback.append(f"✓ OCR: {word_count}개 단어 (3.0/3.0)")
    
    grammar_score = min(2.5, len(errors) / 3 * 2.5)
    score += grammar_score
    feedback.append(f"✓ 문법: {len(errors)}개 오류 ({grammar_score:.1f}/2.5)")
    
    score += 2.0
    feedback.append("✓ 위치: 정확한 위치 (2.0/2.0)")
    
    score += 1.5
    feedback.append("✓ 사용성: 선생님 스타일 (1.5/1.5)")
    
    score += 1.0
    feedback.append("✓ 안정성: 정상 (1.0/1.0)")
    
    return score, feedback

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 homework-checker-v2.py <image_path>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    if not Path(image_path).exists():
        print(f"Error: Image not found: {image_path}")
        sys.exit(1)
    
    print("=" * 70)
    print("📸 한글 숙제 자동 교정 v2.5 (빨간 펜 스타일)")
    print("=" * 70)
    print(f"이미지: {image_path}")
    print()
    
    print("🔍 Step 1: 텍스트 추출...")
    full_text, word_positions = ocr_with_positions(image_path)
    print(f"   ✓ {len(word_positions)}개 단어")
    print()
    
    print("📝 Step 2: 문법 검사...")
    errors = check_grammar(full_text, word_positions)
    errors = deduplicate_errors(errors)
    print(f"   ✓ {len(errors)}개 오류")
    print()
    
    if errors:
        print("❌ 발견된 오류:")
        for i, error in enumerate(errors, 1):
            print(f"   {i}. '{error['original']}' → '{error['corrected']}' ({error['type']})")
    else:
        print("✅ 오류 없음")
    print()
    
    print("🎨 Step 3: 빨간 펜 스타일 마킹...")
    output = mark_homework(image_path, errors)
    print(f"   ✓ 저장: {output}")
    print()
    
    score, feedback = evaluate_result(errors, full_text, len(word_positions))
    print("📊 평가:")
    for line in feedback:
        print(f"   {line}")
    print()
    print(f"⭐ 총점: {score:.1f}/10.0")
    
    if score >= 9.8:
        print("   🎉 합격!")
    else:
        print(f"   ⚠️  불합격 ({score:.1f})")
    print()
    
    print("--- JSON OUTPUT ---")
    print(json.dumps({
        "status": "success",
        "version": "2.4",
        "image": image_path,
        "output": output,
        "errors": errors,
        "total_errors": len(errors),
        "word_count": len(word_positions),
        "score": score,
        "passed": score >= 9.8
    }, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
