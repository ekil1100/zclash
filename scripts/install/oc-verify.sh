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
      emit_install_result "FAIL" "verify" "" "arg-parse" "use: --target-dir <path>"
      exit 2
      ;;
  esac
done

MARKER="$TARGET_DIR/.zclash_installed"
VERSION_FILE="$TARGET_DIR/.zclash_version"
BIN_SHIM="$TARGET_DIR/zclash"

if [[ ! -f "$MARKER" ]]; then
  emit_install_result "FAIL" "verify" "" "marker-missing" "run install first: bash scripts/install/oc-run.sh install --target-dir $TARGET_DIR"
  exit 1
fi

if [[ ! -f "$VERSION_FILE" ]]; then
  emit_install_result "FAIL" "verify" "" "version-missing" "run install or upgrade to create version file"
  exit 1
fi

if [[ ! -x "$BIN_SHIM" ]]; then
  emit_install_result "FAIL" "verify" "" "binary-missing" "re-run install to restore executable shim"
  exit 1
fi

emit_install_result "PASS" "verify" "$MARKER" "" "run upgrade to bump version when needed"
