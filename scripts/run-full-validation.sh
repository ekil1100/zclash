#!/usr/bin/env bash
set -euo pipefail

# 全链路一键验证：install regression + migrator regression + beta gate
# 用法：bash scripts/run-full-validation.sh

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

failed=()
passed=()

run_step() {
  local name="$1"
  shift
  echo "=== [$name] ==="
  if "$@" >/dev/null 2>&1; then
    passed+=("$name")
    echo "  PASS"
  else
    failed+=("$name")
    echo "  FAIL"
  fi
}

run_step "install-regression" bash scripts/install/run-all-regression.sh
run_step "migrator-regression" bash tools/config-migrator/run-all.sh
run_step "beta-gate" bash scripts/run-beta-gate.sh

total=$(( ${#passed[@]} + ${#failed[@]} ))
result="PASS"
[[ ${#failed[@]} -eq 0 ]] || result="FAIL"

echo ""
echo "FULL_VALIDATION_RESULT=$result"
echo "FULL_VALIDATION_PASS=${#passed[@]}/$total"
echo "FULL_VALIDATION_FAILED=${failed[*]:-none}"

[[ "$result" == "PASS" ]]
