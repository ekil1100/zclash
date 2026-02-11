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
  emit_install_result "FAIL" "install" "" "mkdir" "这个目录当前不可写，请换到你有权限的目录（例如 /tmp/zclash-bin）后重试"
  exit 1
fi

MARKER="$TARGET_DIR/.zclash_installed"
VERSION_FILE="$TARGET_DIR/.zclash_version"
BIN_SHIM="$TARGET_DIR/zclash"

echo "installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$MARKER"
echo "v0.1.0" > "$VERSION_FILE"
cat > "$BIN_SHIM" <<'EOF'
#!/usr/bin/env bash
echo "zclash install shim: use project scripts in development mode"
EOF
chmod +x "$BIN_SHIM"

emit_install_result "PASS" "install" "$MARKER" "" "run verify to confirm runtime prerequisites"
