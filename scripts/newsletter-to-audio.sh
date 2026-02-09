#!/bin/bash
# newsletter-to-audio.sh
# 뉴스레터 텍스트 → 오디오 브리핑 변환
# 사용법: ./newsletter-to-audio.sh "뉴스레터 내용" [output.mp3]

set -e

TEXT="$1"
OUTPUT="${2:-~/Downloads/briefing-$(date +%Y%m%d-%H%M).mp3}"

if [ -z "$TEXT" ]; then
    echo "사용법: $0 \"뉴스레터 내용\" [output.mp3]"
    exit 1
fi

# OpenAI TTS API 사용
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ OPENAI_API_KEY 환경변수 필요"
    exit 1
fi

echo "🎙️ 오디오 생성 중..."

# 4096자 제한 → 청킹 필요
CHAR_LIMIT=4000
TEXT_LENGTH=${#TEXT}

if [ $TEXT_LENGTH -le $CHAR_LIMIT ]; then
    # 단일 요청
    curl -s https://api.openai.com/v1/audio/speech \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"tts-1\",
            \"input\": $(echo "$TEXT" | jq -Rs .),
            \"voice\": \"nova\",
            \"speed\": 1.1
        }" \
        --output "$OUTPUT"
    
    echo "✅ 생성 완료: $OUTPUT"
else
    # 청킹 모드
    echo "📦 텍스트 길이 $TEXT_LENGTH자 → 청킹 모드"
    
    TEMP_DIR=$(mktemp -d)
    CHUNK_NUM=0
    
    # 문장 단위로 분할
    echo "$TEXT" | fold -s -w $CHAR_LIMIT | while read -r CHUNK; do
        CHUNK_NUM=$((CHUNK_NUM + 1))
        CHUNK_FILE="$TEMP_DIR/chunk_$(printf '%03d' $CHUNK_NUM).mp3"
        
        echo "  청크 $CHUNK_NUM 생성 중..."
        curl -s https://api.openai.com/v1/audio/speech \
            -H "Authorization: Bearer $OPENAI_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"tts-1\",
                \"input\": $(echo "$CHUNK" | jq -Rs .),
                \"voice\": \"nova\",
                \"speed\": 1.1
            }" \
            --output "$CHUNK_FILE"
    done
    
    # ffmpeg로 병합
    echo "🔗 청크 병합 중..."
    ffmpeg -y -f concat -safe 0 \
        -i <(for f in "$TEMP_DIR"/chunk_*.mp3; do echo "file '$f'"; done) \
        -c copy "$OUTPUT" 2>/dev/null
    
    rm -rf "$TEMP_DIR"
    echo "✅ 생성 완료: $OUTPUT"
fi

# 파일 정보
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT" 2>/dev/null | cut -d. -f1)
SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "📊 길이: ${DURATION}초 / 크기: $SIZE"
