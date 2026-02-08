#!/usr/bin/env python3
"""
한글 숙제 자동 교정 시스템
Korean Homework Auto-Correction System

Usage:
    python3 korean-homework-checker.py <image_path> [corrections.json]
"""

import sys
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

def load_corrections(corrections_file):
    """교정 데이터 로드 (JSON)"""
    if not Path(corrections_file).exists():
        return []
    
    with open(corrections_file, 'r', encoding='utf-8') as f:
        return json.load(f)

def mark_image(image_path, corrections, output_path=None):
    """
    이미지에 교정 마킹
    
    corrections format:
    [
        {
            "line": 1,
            "original": "잘못된 표현",
            "corrected": "올바른 표현",
            "position": {"x": 100, "y": 200, "width": 150, "height": 30}
        },
        ...
    ]
    """
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    
    # 기본 폰트 (시스템에 따라 조정 필요)
    try:
        # macOS 한글 폰트
        font_error = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 20)
        font_correct = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleGothic.ttf", 24)
    except:
        # Fallback
        font_error = ImageFont.load_default()
        font_correct = ImageFont.load_default()
    
    for correction in corrections:
        pos = correction.get("position", {})
        x, y = pos.get("x", 0), pos.get("y", 0)
        width, height = pos.get("width", 100), pos.get("height", 25)
        
        # 빨간 밑줄 (오류 표시)
        draw.line(
            [(x, y + height), (x + width, y + height)],
            fill="red",
            width=3
        )
        
        # 초록 박스 (교정 표시)
        corrected_text = correction.get("corrected", "")
        draw.rectangle(
            [(x, y + height + 10), (x + width, y + height + 40)],
            outline="green",
            width=2
        )
        draw.text(
            (x + 5, y + height + 12),
            corrected_text,
            fill="green",
            font=font_correct
        )
    
    # 저장
    if output_path is None:
        output_path = str(Path(image_path).stem) + "_corrected.jpg"
    
    img.save(output_path, quality=95)
    print(f"✅ 교정 이미지 저장: {output_path}")
    return output_path

def main():
    if len(sys.argv) < 2:
        print("사용법: python3 korean-homework-checker.py <이미지> [corrections.json]")
        sys.exit(1)
    
    image_path = sys.argv[1]
    corrections_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    if not Path(image_path).exists():
        print(f"❌ 이미지 파일 없음: {image_path}")
        sys.exit(1)
    
    # 교정 데이터 로드
    if corrections_file:
        corrections = load_corrections(corrections_file)
    else:
        # 샘플 데이터 (테스트용)
        corrections = [
            {
                "line": 1,
                "original": "얼이 나요",
                "corrected": "열이 나요",
                "position": {"x": 600, "y": 230, "width": 80, "height": 25}
            },
            {
                "line": 2,
                "original": "꽃얼이나요",
                "corrected": "콧물이 나요",
                "position": {"x": 600, "y": 440, "width": 100, "height": 25}
            }
        ]
    
    # 마킹 실행
    output = mark_image(image_path, corrections)
    print(f"🎯 교정 완료: {len(corrections)}개 오류 마킹")

if __name__ == "__main__":
    main()
