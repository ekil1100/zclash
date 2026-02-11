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
      emit_install_result "FAIL" "install" "" "arg-parse" "use: --target-dir <path>"
      exit 2
      ;;
  esac
done

if [[ -z "$TARGET_DIR" ]]; then
  emit_install_result "FAIL" "install" "" "arg-parse" "target dir is empty"
  exit 2
fi

if ! mkdir -p "$TARGET_DIR" 2>/dev/null; then
  emit_install_result "FAIL" "install" "" "mkdir" "check permission or use writable --target-dir"
  exit 1
fi

MARKER="$TARGET_DIR/.zclash_installed"
VERSION_FILE="$TARGET_DIR/.zclash_version"

echo "installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$MARKER"
echo "v0.1.0" > "$VERSION_FILE"

emit_install_result "PASS" "install" "$MARKER" "" "run verify to confirm runtime prerequisites"
