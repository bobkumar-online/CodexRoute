#!/bin/bash
# list-codex-files.sh — Lists all files/dirs inside ~/.codex
# Usage: bash list-codex-files.sh [depth]

DEPTH="${1:-3}"
BASE="$HOME/.codex"

if [[ ! -d "$BASE" ]]; then
  echo "ERROR: $BASE not found"
  exit 1
fi

echo "=== ~/.codex contents (depth $DEPTH) ==="
echo ""

echo "--- Directories ---"
find "$BASE" -maxdepth "$DEPTH" -type d 2>/dev/null \
   | sed "s|^${BASE}/|~/.codex/|" \
   | sort

echo ""
echo "--- Files (by size, top 60) ---"
find "$BASE" -maxdepth "$DEPTH" -type f -printf '%s %p\n' 2>/dev/null \
   | sort -rn \
   | head -60 \
   | while read size path; do
       echo "$(printf '%8s' "$(numfmt --to=iec $size)")" "$(echo $path | sed "s|^${BASE}/|~/.codex/|")"
     done

echo ""
echo "--- Hidden top-level entries ---"
ls -la "$BASE" | grep '^\.' || true

TOTAL_FILES=$(find "$BASE" -maxdepth "$DEPTH" -type f 2>/dev/null | wc -l | tr -d ' ')
TOTAL_DIRS=$(find "$BASE" -maxdepth "$DEPTH" -type d 2>/dev/null | wc -l | tr -d ' ')
TOTAL_SIZE=$(du -sh "$BASE" 2>/dev/null | awk '{print $1}')
echo ""
echo "Total: $TOTAL_DIRS directories, $TOTAL_FILES files ($TOTAL_SIZE)"
