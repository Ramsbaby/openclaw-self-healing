#!/usr/bin/env python3
"""
Korean Grammar Marker - 한국어 문법 교정 이미지 마킹 도구

Usage:
    python3 korean-grammar-marker.py <input_image> <corrections_json> <output_image>

corrections_json format:
    [
        {
            "line": 1,
            "original": "나는 학교에 갔어요",
            "corrected": "학교에 갔어요",
            "error_type": "redundant",
            "position": {"x": 50, "y": 100, "width": 200}
        },
        ...
    ]

Or pipe JSON via stdin:
    echo '[...]' | python3 korean-grammar-marker.py input.jpg - output.jpg
"""

import sys
import json
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

# Configuration
CONFIG = {
    "fonts": {
        "korean": [
            "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
            "/System/Library/Fonts/Supplemental/AppleMyungjo.ttf",
            "/System/Library/Fonts/Supplemental/NotoSansGothic-Regular.ttf",
            "/usr/share/fonts/truetype/nanum/NanumGothic.ttf",  # Linux
        ],
        "fallback": "/System/Library/Fonts/Supplemental/AppleGothic.ttf"
    },
    "colors": {
        "error_underline": (255, 0, 0),        # Red
        "error_box": (255, 200, 200, 180),     # Light red with alpha
        "correction_text": (0, 150, 0),         # Green
        "correction_bg": (255, 255, 255, 220),  # White with alpha
        "line_number": (100, 100, 100),         # Gray
    },
    "sizes": {
        "font_correction": 16,
        "font_line_num": 12,
        "underline_width": 3,
        "box_padding": 5,
        "correction_offset_y": 25,
    }
}


def find_korean_font():
    """Find available Korean font."""
    for font_path in CONFIG["fonts"]["korean"]:
        if Path(font_path).exists():
            return font_path
    return CONFIG["fonts"]["fallback"]


def load_font(size):
    """Load font with fallback."""
    font_path = find_korean_font()
    try:
        return ImageFont.truetype(font_path, size)
    except Exception:
        return ImageFont.load_default()


def draw_error_underline(draw, x, y, width, color=None):
    """Draw wavy underline to indicate error."""
    if color is None:
        color = CONFIG["colors"]["error_underline"]
    
    underline_width = CONFIG["sizes"]["underline_width"]
    
    # Draw wavy line
    wave_height = 3
    wave_length = 6
    for i in range(0, width, wave_length):
        offset = wave_height if (i // wave_length) % 2 == 0 else 0
        draw.line(
            [(x + i, y + offset), (x + i + wave_length // 2, y + wave_height - offset)],
            fill=color,
            width=underline_width
        )


def draw_correction_box(draw, x, y, text, font):
    """Draw correction text with background box."""
    # Get text size
    bbox = font.getbbox(text)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    padding = CONFIG["sizes"]["box_padding"]
    
    # Draw background box
    box_coords = [
        x - padding,
        y - padding,
        x + text_width + padding,
        y + text_height + padding
    ]
    draw.rectangle(box_coords, fill=CONFIG["colors"]["correction_bg"])
    
    # Draw border
    draw.rectangle(box_coords, outline=CONFIG["colors"]["correction_text"], width=1)
    
    # Draw text
    draw.text(
        (x, y),
        text,
        font=font,
        fill=CONFIG["colors"]["correction_text"]
    )
    
    return text_width + padding * 2, text_height + padding * 2


def draw_strikethrough(draw, x, y, width, height):
    """Draw strikethrough line over original text."""
    mid_y = y + height // 2
    draw.line(
        [(x, mid_y), (x + width, mid_y)],
        fill=CONFIG["colors"]["error_underline"],
        width=2
    )


def process_corrections(image_path, corrections, output_path):
    """
    Process image with corrections overlay.
    
    Args:
        image_path: Path to input image
        corrections: List of correction dictionaries
        output_path: Path for output image
    """
    # Load image
    img = Image.open(image_path)
    
    # Convert to RGBA for transparency support
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    
    # Create overlay layer
    overlay = Image.new("RGBA", img.size, (255, 255, 255, 0))
    draw = ImageDraw.Draw(overlay)
    
    # Load fonts
    font_correction = load_font(CONFIG["sizes"]["font_correction"])
    font_line_num = load_font(CONFIG["sizes"]["font_line_num"])
    
    # Process each correction
    for i, correction in enumerate(corrections):
        pos = correction.get("position", {})
        x = pos.get("x", 50)
        y = pos.get("y", 50 + i * 60)
        width = pos.get("width", 200)
        height = pos.get("height", 20)
        
        original = correction.get("original", "")
        corrected = correction.get("corrected", "")
        error_type = correction.get("error_type", "grammar")
        line_num = correction.get("line", i + 1)
        
        # Draw error underline
        draw_error_underline(draw, x, y + height, width)
        
        # Draw correction text below
        correction_y = y + height + CONFIG["sizes"]["correction_offset_y"]
        correction_text = f"→ {corrected}"
        draw_correction_box(draw, x, correction_y, correction_text, font_correction)
        
        # Draw line number indicator
        line_text = f"L{line_num}"
        draw.text(
            (x - 30, y),
            line_text,
            font=font_line_num,
            fill=CONFIG["colors"]["line_number"]
        )
    
    # Composite overlay onto original
    result = Image.alpha_composite(img, overlay)
    
    # Convert back to RGB for saving as JPEG
    if output_path.lower().endswith(('.jpg', '.jpeg')):
        result = result.convert("RGB")
    
    result.save(output_path)
    print(f"✅ Saved: {output_path}")
    return output_path


def auto_detect_positions(image_path, corrections):
    """
    Auto-detect text positions in image (basic implementation).
    For more accurate detection, integrate with OCR.
    """
    img = Image.open(image_path)
    width, height = img.size
    
    # Simple vertical distribution
    num_corrections = len(corrections)
    if num_corrections == 0:
        return corrections
    
    line_height = min(60, height // (num_corrections + 1))
    margin_x = 50
    margin_y = 50
    
    for i, correction in enumerate(corrections):
        if "position" not in correction:
            correction["position"] = {
                "x": margin_x,
                "y": margin_y + i * line_height,
                "width": width - margin_x * 2,
                "height": 25
            }
    
    return corrections


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    
    input_image = sys.argv[1]
    corrections_source = sys.argv[2]
    output_image = sys.argv[3]
    
    # Load corrections
    if corrections_source == "-":
        corrections = json.load(sys.stdin)
    else:
        with open(corrections_source, "r", encoding="utf-8") as f:
            corrections = json.load(f)
    
    # Auto-detect positions if not provided
    corrections = auto_detect_positions(input_image, corrections)
    
    # Process image
    process_corrections(input_image, corrections, output_image)


if __name__ == "__main__":
    main()
