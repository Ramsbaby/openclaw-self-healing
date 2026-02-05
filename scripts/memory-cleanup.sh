#!/bin/bash
# Memory Cleanup: Archive old daily logs to MEMORY.md
# Runs weekly (Monday 03:30 KST)

set -e

WORKSPACE="$HOME/openclaw"
MEMORY_DIR="$WORKSPACE/memory"
MEMORY_FILE="$MEMORY_DIR/MEMORY.md"
ARCHIVE_DIR="$MEMORY_DIR/archive"
CUTOFF_DAYS=14

# Create archive directory if needed
mkdir -p "$ARCHIVE_DIR"

# Find daily logs older than CUTOFF_DAYS
find "$MEMORY_DIR" -name "2026-*.md" -type f -mtime +$CUTOFF_DAYS | while read -r file; do
  filename=$(basename "$file")
  echo "📦 Archiving: $filename"
  
  # Move to archive
  mv "$file" "$ARCHIVE_DIR/"
  
  echo "✅ Archived to archive/$filename"
done

echo "🧹 Memory cleanup finished"
