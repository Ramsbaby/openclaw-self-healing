#!/bin/bash
# 주간 메모리 압축 스크립트
# 매주 일요일 23:00 실행

set -euo pipefail

MEMORY_DIR="$HOME/openclaw/memory"
ARCHIVE_DIR="$MEMORY_DIR/archive"
DATE=$(date '+%Y-%m-%d')
WEEK_AGO=$(date -v-7d '+%Y-%m-%d' 2>/dev/null || date -d '7 days ago' '+%Y-%m-%d')

echo "🗂️ 메모리 압축 시작: $DATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Archive 디렉토리 생성
mkdir -p "$ARCHIVE_DIR"

# 1. 7일 이상 된 daily notes 아카이브
echo "📁 7일 이상 된 daily notes 아카이브 중..."
find "$MEMORY_DIR" -maxdepth 1 -name "202[0-9]-[0-9][0-9]-[0-9][0-9].md" -mtime +7 | while read -r file; do
  basename=$(basename "$file")
  if [[ ! -f "$ARCHIVE_DIR/$basename" ]]; then
    mv "$file" "$ARCHIVE_DIR/"
    echo "  → $basename"
  fi
done

# 2. 7일 이상 된 품질 체크 삭제
echo "🗑️ 7일 이상 된 품질 체크 삭제 중..."
find "$MEMORY_DIR" -maxdepth 1 -name "quality-check-*.md" -mtime +7 -delete -print | while read -r file; do
  echo "  → $(basename "$file")"
done

# 3. 빈 파일 정리
echo "🧹 빈 파일 정리 중..."
find "$MEMORY_DIR" -maxdepth 1 -type f -empty -delete -print | while read -r file; do
  echo "  → $(basename "$file")"
done

# 4. 통계
TOTAL_FILES=$(find "$MEMORY_DIR" -maxdepth 1 -type f | wc -l)
ARCHIVE_FILES=$(find "$ARCHIVE_DIR" -type f 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "$MEMORY_DIR" 2>/dev/null | cut -f1)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 메모리 압축 완료"
echo "  - 현재 파일: $TOTAL_FILES개"
echo "  - 아카이브: $ARCHIVE_FILES개"
echo "  - 총 크기: $TOTAL_SIZE"
