#!/usr/bin/env python3
"""
Test script for korean-grammar-marker.py
Creates a sample homework image and applies corrections.
"""

from PIL import Image, ImageDraw, ImageFont
import json
import subprocess
from pathlib import Path

# Create test homework image
def create_test_homework():
    """Create a sample Korean homework image."""
    img = Image.new("RGB", (800, 400), "white")
    draw = ImageDraw.Draw(img)
    
    # Load Korean font
    font_path = "/System/Library/Fonts/Supplemental/AppleGothic.ttf"
    try:
        font = ImageFont.truetype(font_path, 24)
    except:
        font = ImageFont.load_default()
    
    # Sample Korean sentences with errors
    sentences = [
        "1. 나는 어제 학교에 갔습니다.",
        "2. 맛있는 먹었어요.",           # Error: missing noun
        "3. 친구를 만나서 기뻤어요.",
        "4. 한국어 공부는 재미있다.",     # Could use more natural ending
        "5. 오늘 날씨가 아주 춥네요.",
    ]
    
    y = 50
    for sentence in sentences:
        draw.text((50, y), sentence, font=font, fill="black")
        y += 60
    
    # Add title
    try:
        title_font = ImageFont.truetype(font_path, 18)
    except:
        title_font = font
    draw.text((50, 10), "한국어 숙제 - Korean Homework", font=title_font, fill="gray")
    
    output_path = Path("/tmp/test_homework.png")
    img.save(output_path)
    print(f"✅ Created test image: {output_path}")
    return str(output_path)


def create_corrections():
    """Create sample corrections JSON."""
    corrections = [
        {
            "line": 2,
            "original": "맛있는 먹었어요",
            "corrected": "맛있게 먹었어요",
            "error_type": "adverb",
            "position": {"x": 50, "y": 108, "width": 180, "height": 25}
        },
        {
            "line": 4,
            "original": "재미있다",
            "corrected": "재미있어요",
            "error_type": "politeness",
            "position": {"x": 280, "y": 228, "width": 90, "height": 25}
        }
    ]
    
    corrections_path = Path("/tmp/test_corrections.json")
    with open(corrections_path, "w", encoding="utf-8") as f:
        json.dump(corrections, f, ensure_ascii=False, indent=2)
    
    print(f"✅ Created corrections: {corrections_path}")
    return str(corrections_path)


def run_marker(input_img, corrections_json, output_img):
    """Run the grammar marker script."""
    script_path = Path.home() / "openclaw/scripts/korean-grammar-marker.py"
    
    result = subprocess.run(
        ["python3", str(script_path), input_img, corrections_json, output_img],
        capture_output=True,
        text=True
    )
    
    if result.returncode == 0:
        print(f"✅ Output saved: {output_img}")
        print(result.stdout)
    else:
        print(f"❌ Error: {result.stderr}")
    
    return result.returncode == 0


if __name__ == "__main__":
    # Create test files
    homework_img = create_test_homework()
    corrections_json = create_corrections()
    output_img = "/tmp/test_homework_corrected.png"
    
    # Run marker
    success = run_marker(homework_img, corrections_json, output_img)
    
    if success:
        print(f"\n🎉 Test complete! Check: {output_img}")
    else:
        print("\n❌ Test failed")
