#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"
source "$(cd "$(dirname "$0")" && pwd)/next-step-dict.sh"

TARGET_DIR="/usr/local/bin"
REQUIRE_CMD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-dir)
      TARGET_DIR="${2:-}"
      shift 2
      ;;
    --require-cmd)
      REQUIRE_CMD="${2:-}"
      shift 2
      ;;
    *)
      emit_install_result "FAIL" "verify" "" "arg-parse" "$(install_next_step arg_parse)"
      exit 2
      ;;
  esac
done

MARKER="$TARGET_DIR/.zclash_installed"
VERSION_FILE="$TARGET_DIR/.zclash_version"
BIN_SHIM="$TARGET_DIR/zclash"

if [[ ! -f "$MARKER" ]]; then
  emit_install_result "FAIL" "verify" "" "marker-missing" "$(install_next_step marker_missing)"
  exit 1
fi

if [[ ! -f "$VERSION_FILE" ]]; then
  emit_install_result "FAIL" "verify" "" "version-missing" "$(install_next_step version_missing)"
  exit 1
fi

if [[ ! -x "$BIN_SHIM" ]]; then
  emit_install_result "FAIL" "verify" "" "binary-missing" "$(install_next_step binary_missing)"
  exit 1
fi

if [[ -n "$REQUIRE_CMD" ]] && ! command -v "$REQUIRE_CMD" >/dev/null 2>&1; then
  emit_install_result "FAIL" "verify" "" "dependency-missing" "$(install_next_step dependency_missing)"
  exit 1
fi

emit_install_result "PASS" "verify" "$MARKER" "" "run upgrade to bump version when needed"
