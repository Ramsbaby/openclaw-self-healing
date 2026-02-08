#!/bin/bash
#
# Grammar Correction Workflow
# 
# Usage: 
#   grammar-correction-workflow.sh <input_image> [output_image]
#
# This script is called by Jarvis after vision analysis.
# It takes the corrections JSON from stdin and produces a marked-up image.
#
# Example:
#   echo '[{"line":1,"original":"맛있는","corrected":"맛있게","position":{"x":50,"y":100,"width":100,"height":25}}]' | \
#   ./grammar-correction-workflow.sh input.jpg output.jpg
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER_SCRIPT="$SCRIPT_DIR/korean-grammar-marker.py"

INPUT_IMAGE="$1"
OUTPUT_IMAGE="${2:-/tmp/grammar_corrected_$(date +%s).png}"

if [ -z "$INPUT_IMAGE" ]; then
    echo "Usage: $0 <input_image> [output_image]"
    echo "Pass corrections JSON via stdin"
    exit 1
fi

if [ ! -f "$INPUT_IMAGE" ]; then
    echo "Error: Input image not found: $INPUT_IMAGE"
    exit 1
fi

# Run the marker script with JSON from stdin
python3 "$MARKER_SCRIPT" "$INPUT_IMAGE" - "$OUTPUT_IMAGE"

# Output the result path for Jarvis to use
echo "$OUTPUT_IMAGE"
