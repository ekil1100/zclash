#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

TARGET_DIR="/usr/local/bin"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-dir)
      TARGET_DIR="${2:-}"
      shift 2
      ;;
    *)
      emit_install_result "FAIL" "rollback" "" "arg-parse" "use: --target-dir <path>"
      exit 2
      ;;
  esac
done

if [[ -z "$TARGET_DIR" ]]; then
  emit_install_result "FAIL" "rollback" "" "arg-parse" "target dir is empty"
  exit 2
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  emit_install_result "PASS" "rollback" "$TARGET_DIR" "" "none"
  exit 0
fi

TARGETS=(
  "$TARGET_DIR/.zclash_installed"
  "$TARGET_DIR/.zclash_version"
  "$TARGET_DIR/zclash"
)

removed=0
for path in "${TARGETS[@]}"; do
  if [[ -e "$path" ]]; then
    if rm -f "$path" 2>/dev/null; then
      removed=$((removed+1))
    else
      emit_install_result "FAIL" "rollback" "$path" "remove" "check permissions then rerun rollback"
      exit 1
    fi
  fi
done

emit_install_result "PASS" "rollback" "$TARGET_DIR" "" "removed=$removed"
