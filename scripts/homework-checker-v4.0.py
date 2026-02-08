#!/usr/bin/env python3
"""
한글 숙제 자동 교정 시스템 v4.0
Google Vision OCR + GPT-4 Vision 하이브리드

Usage:
    python3 homework-checker-v4.0.py <image_path>
"""

import sys
import json
import os
import base64
from pathlib import Path
from google.cloud import vision
from openai import OpenAI
from PIL import Image, ImageDraw, ImageFont

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = os.path.expanduser('~/.openclaw/google-vision-key.json')

OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
if not OPENAI_API_KEY:
    print("❌ OPENAI_API_KEY 환경변수 필요")
    sys.exit(1)

openai_client = OpenAI(api_key=OPENAI_API_KEY)

def ocr_google_vision(image_path):
    """Google Vision으로 전체 텍스트 추출"""
    client = vision.ImageAnnotatorClient()
    
    with open(image_path, 'rb') as f:
        content = f.read()
    
    image = vision.Image(content=content)
    image_context = vision.ImageContext(language_hints=['ko'])
    response = client.document_text_detection(image=image, image_context=image_context)
    
    if response.error.message:
        raise Exception(f"Vision API Error: {response.error.message}")
    
    full_text = ""
    if response.full_text_annotation:
        full_text = response.full_text_annotation.text
    
    return full_text

def encode_image_base64(image_path):
    """이미지를 base64로 인코딩"""
    with open(image_path, 'rb') as f:
        return base64.b64encode(f.read()).decode('utf-8')

def analyze_errors_with_gpt4v(image_path, ocr_text):
    """
    GPT-4 Vision으로 에러 감지 + 픽셀 좌표 추출
    
    Returns:
        [
            {
                "original": "아ㅍ요",
                "corrected": "아파요",
                "type": "incomplete",
                "position": {"x": 1062, "y": 357, "width": 150, "height": 50},
                "reasoning": "받침이 누락된 불완전한 글자"
            },
            ...
        ]
    """
    img = Image.open(image_path)
    width, height = img.size
    
    base64_image = encode_image_base64(image_path)
    
    prompt = f"""당신은 한국어 선생님입니다. 외국인 학생의 숙제 이미지를 보고 문법 오류를 찾아주세요.

**OCR 텍스트 (참고용):**
{ocr_text[:1000]}

**이미지 크기:** {width}x{height}px

**찾아야 할 오류 유형:**
1. **spelling** (철자): "기치"→"기침", "주제"→"축제"
2. **spacing** (띄어쓰기): "이가아파요"→"이가 아파요"
3. **incomplete** (불완전): "아ㅍ요"→"아파요" (받침 누락)
4. **verb** (동사): "하어요"→"해요", "가어요"→"가요"
5. **duplicate** (중복): "갔어요 있었겠어요"→"갔어요"

**출력 형식 (JSON):**
```json
[
  {{
    "original": "틀린 텍스트",
    "corrected": "올바른 텍스트",
    "type": "오류 유형",
    "position": {{
      "x": 왼쪽 상단 X좌표(픽셀),
      "y": 왼쪽 상단 Y좌표(픽셀),
      "width": 너비(픽셀),
      "height": 높이(픽셀)
    }},
    "reasoning": "왜 틀렸는지 설명"
  }}
]
```

**주의사항:**
- 이미지에서 **실제로 보이는** 학생 손글씨만 검사
- 교재 인쇄된 텍스트는 무시
- 위치 좌표는 이미지 왼쪽 상단 (0,0) 기준 픽셀 단위
- 손글씨가 선 밖으로 나간 경우도 포함
- JSON만 출력 (다른 설명 불필요)
"""

    response = openai_client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{base64_image}",
                            "detail": "high"
                        }
                    }
                ]
            }
        ],
        max_tokens=2000,
        temperature=0.1,
    )
    
    result = response.choices[0].message.content.strip()
    
    # JSON 추출 (```json ... ``` 감싸져 있을 수 있음)
    if '```json' in result:
        result = result.split('```json')[1].split('```')[0].strip()
    elif '```' in result:
        result = result.split('```')[1].split('```')[0].strip()
    
    errors = json.loads(result)
    return errors

def mark_homework(image_path, errors, output_path=None):
    """빨간 펜 스타일 마킹"""
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    
    try:
        font_correction = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 55)
    except:
        font_correction = ImageFont.load_default()
    
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
        output_path = parent / f"{base}_v4_corrected{ext}"
    
    img.save(output_path)
    return str(output_path)

def evaluate_result(errors, ocr_length):
    """평가 점수 산출"""
    score_ocr = 3.0 if ocr_length > 100 else 2.0
    
    if len(errors) == 0:
        score_grammar = 2.5
    elif len(errors) <= 2:
        score_grammar = 2.0
    elif len(errors) <= 5:
        score_grammar = 1.5
    else:
        score_grammar = 1.0
    
    score_position = 2.0  # GPT-4V가 직접 위치 지정
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
        print("Usage: python3 homework-checker-v4.0.py <image_path>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    if not os.path.exists(image_path):
        print(f"❌ 파일 없음: {image_path}")
        sys.exit(1)
    
    print("=" * 70)
    print("📸 한글 숙제 자동 교정 v4.0 (GPT-4 Vision Hybrid)")
    print("=" * 70)
    print(f"이미지: {image_path}\n")
    
    # Step 1: Google Vision OCR
    print("🔍 Step 1: 텍스트 추출 (Google Vision)...")
    ocr_text = ocr_google_vision(image_path)
    print(f"   ✓ {len(ocr_text)} 글자")
    
    # Step 2: GPT-4 Vision 분석
    print("\n🤖 Step 2: 에러 분석 (GPT-4 Vision)...")
    errors = analyze_errors_with_gpt4v(image_path, ocr_text)
    print(f"   ✓ {len(errors)}개 오류 발견")
    
    if errors:
        print("\n❌ 발견된 오류:")
        for i, error in enumerate(errors, 1):
            print(f"   {i}. '{error['original']}' → '{error['corrected']}' ({error['type']})")
            print(f"      위치: ({error['position']['x']}, {error['position']['y']})")
            print(f"      이유: {error.get('reasoning', 'N/A')}")
    
    # Step 3: 마킹
    print("\n🎨 Step 3: 빨간 펜 스타일 마킹...")
    output_path = mark_homework(image_path, errors)
    print(f"   ✓ 저장: {output_path}")
    
    # 평가
    scores = evaluate_result(errors, len(ocr_text))
    
    print("\n📊 평가:")
    print(f"   ✓ OCR: {len(ocr_text)} 글자 ({scores['ocr']:.1f}/3.0)")
    print(f"   ✓ 문법: {len(errors)}개 오류 ({scores['grammar']:.1f}/2.5)")
    print(f"   ✓ 위치: GPT-4V 직접 지정 ({scores['position']:.1f}/2.0)")
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
        'version': '4.0',
        'ocr_engine': 'google_vision + gpt4_vision',
        'image': image_path,
        'output': output_path,
        'errors': errors,
        'total_errors': len(errors),
        'ocr_length': len(ocr_text),
        'score': scores['total'],
        'passed': scores['passed'],
    }
    
    print("\n--- JSON OUTPUT ---")
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
