#!/usr/bin/env bash
set -euo pipefail

# 回归报告归档清理
# 保留最近 10 次 + latest，其余归档到 history/

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPORTS_DIR="$ROOT_DIR/tools/config-migrator/reports"
HISTORY_DIR="$REPORTS_DIR/history"

mkdir -p "$HISTORY_DIR"

echo "=== Reports Cleanup ==="
echo "Reports dir: $REPORTS_DIR"

# Count total files
total_files=$(find "$REPORTS_DIR" -maxdepth 1 -type f \( -name "*.json" -o -name "*.jsonl" -o -name "*.yaml" \) | wc -l | tr -d ' ')
echo "Total files: $total_files"

# If more than 10 files, archive oldest
if [[ $total_files -gt 10 ]]; then
  archived=0
  ls -t "$REPORTS_DIR"/*.json "$REPORTS_DIR"/*.jsonl "$REPORTS_DIR"/*.yaml 2>/dev/null | tail -n +11 | while read -r f; do
    if [[ -f "$f" && "$(basename "$f")" != "samples-summary.json" ]]; then
      echo "Archiving: $(basename "$f")"
      mv "$f" "$HISTORY_DIR/"
      archived=$((archived + 1))
    fi
  done
  echo "✅ Archived files to history/"
else
  echo "✅ No cleanup needed (≤10 files)"
fi

# Show current state
echo ""
echo "Current reports:"
active=$(find "$REPORTS_DIR" -maxdepth 1 -type f \( -name "*.json" -o -name "*.jsonl" -o -name "*.yaml" \) 2>/dev/null | wc -l | tr -d ' ')
archived=$(find "$HISTORY_DIR" -maxdepth 1 -type f \( -name "*.json" -o -name "*.jsonl" -o -name "*.yaml" \) 2>/dev/null | wc -l | tr -d ' ')
echo "  Active: $active"
echo "  Archived: $archived"
echo ""
echo "REPORT_CLEANUP_RESULT=PASS"
