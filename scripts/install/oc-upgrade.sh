#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"
source "$(cd "$(dirname "$0")" && pwd)/next-step-dict.sh"

TARGET_DIR="/usr/local/bin"
VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-dir)
      TARGET_DIR="${2:-}"
      shift 2
      ;;
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    *)
      emit_install_result "FAIL" "upgrade" "" "arg-parse" "$(install_next_step arg_parse)"
      exit 2
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  emit_install_result "FAIL" "upgrade" "" "version-missing" "$(install_next_step version_missing)"
  exit 2
fi

MARKER="$TARGET_DIR/.zclash_installed"
VERSION_FILE="$TARGET_DIR/.zclash_version"

if [[ ! -f "$MARKER" ]]; then
  emit_install_result "FAIL" "upgrade" "" "not-installed" "$(install_next_step not_installed)"
  exit 1
fi

if [[ ! -f "$VERSION_FILE" ]]; then
  emit_install_result "FAIL" "upgrade" "" "version-missing" "$(install_next_step version_missing)"
  exit 1
fi

echo "$VERSION" > "$VERSION_FILE"

emit_install_result "PASS" "upgrade" "$VERSION_FILE" "" "run verify after upgrade to ensure compatibility"
