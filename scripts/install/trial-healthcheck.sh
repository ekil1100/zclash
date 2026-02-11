#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"
source "$(cd "$(dirname "$0")" && pwd)/next-step-dict.sh"

TARGET_DIR="/usr/local/bin"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-dir)
      TARGET_DIR="${2:-}"
      shift 2
      ;;
    *)
      emit_install_result "FAIL" "healthcheck" "" "arg-parse" "$(install_next_step arg_parse)"
      exit 2
      ;;
  esac
done

checks=()
failed=()

add_check() {
  local id="$1" result="$2" detail="$3"
  checks+=("{\"id\":\"$id\",\"result\":\"$result\",\"detail\":\"$detail\"}")
  [[ "$result" == "PASS" ]] || failed+=("$id")
}

# 1) install completeness
MARKER="$TARGET_DIR/.zclash_installed"
VERSION_FILE="$TARGET_DIR/.zclash_version"
BIN_SHIM="$TARGET_DIR/zclash"

if [[ -f "$MARKER" && -f "$VERSION_FILE" && -x "$BIN_SHIM" ]]; then
  add_check "install_completeness" "PASS" "marker+version+shim all present"
else
  missing=""
  [[ -f "$MARKER" ]] || missing+="marker,"
  [[ -f "$VERSION_FILE" ]] || missing+="version,"
  [[ -x "$BIN_SHIM" ]] || missing+="shim,"
  add_check "install_completeness" "FAIL" "missing: ${missing%,}"
fi

# 2) version consistency
if [[ -f "$VERSION_FILE" ]]; then
  ver="$(cat "$VERSION_FILE")"
  if [[ "$ver" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    add_check "version_format" "PASS" "$ver"
  else
    add_check "version_format" "FAIL" "invalid format: $ver"
  fi
else
  add_check "version_format" "FAIL" "version file missing"
fi

# 3) config validity (check if marker is readable)
if [[ -f "$MARKER" ]] && grep -q "installed_at=" "$MARKER" 2>/dev/null; then
  add_check "config_validity" "PASS" "install marker readable"
else
  add_check "config_validity" "FAIL" "install marker corrupt or missing"
fi

# 4) network connectivity (basic DNS check)
if command -v ping >/dev/null 2>&1 && ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
  add_check "network_connectivity" "PASS" "1.1.1.1 reachable"
elif command -v curl >/dev/null 2>&1 && curl -s --connect-timeout 3 https://1.1.1.1 >/dev/null 2>&1; then
  add_check "network_connectivity" "PASS" "1.1.1.1 reachable via curl"
else
  add_check "network_connectivity" "FAIL" "1.1.1.1 unreachable"
fi

total=${#checks[@]}
pass=$((total - ${#failed[@]}))
result="PASS"
[[ ${#failed[@]} -eq 0 ]] || result="FAIL"

report="/tmp/zclash-healthcheck-$(date +%s).json"
printf '{\n  "result":"%s",\n  "pass_count":%d,\n  "total_count":%d,\n  "failed_checks":["%s"],\n  "checks":[\n    %s\n  ]\n}\n' \
  "$result" "$pass" "$total" "$(IFS='","'; echo "${failed[*]:-}")" "$(IFS=,; echo "${checks[*]}")" > "$report"

echo "INSTALL_RESULT=$result"
echo "INSTALL_ACTION=healthcheck"
echo "INSTALL_REPORT=$report"
echo "INSTALL_FAILED_STEP=$(IFS=,; echo "${failed[*]:-}")"
if [[ "$result" == "PASS" ]]; then
  echo "INSTALL_NEXT_STEP=所有检查通过，可正常使用"
else
  echo "INSTALL_NEXT_STEP=按失败项修复后重新检查"
fi
echo "INSTALL_SUMMARY=healthcheck $pass/$total passed, failed=${failed[*]:-none}"

echo "HEALTHCHECK_RESULT=$result"
echo "HEALTHCHECK_REPORT=$report"

[[ "$result" == "PASS" ]]
