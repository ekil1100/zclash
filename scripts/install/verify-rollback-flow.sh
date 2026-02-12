#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT_DIR/scripts/install/oc-run.sh"
OUT_DIR="/tmp/zc-rollback-regression"
mkdir -p "$OUT_DIR"

failed=()

# case1: rollback success
TARGET_OK="$OUT_DIR/ok-target"
bash "$RUNNER" install --target-dir "$TARGET_OK" > "$OUT_DIR/case1.install.out" 2>&1
if bash "$RUNNER" rollback --target-dir "$TARGET_OK" > "$OUT_DIR/case1.rollback.out" 2>&1 \
  && grep -q 'INSTALL_RESULT=PASS' "$OUT_DIR/case1.rollback.out" \
  && grep -q 'INSTALL_ACTION=rollback' "$OUT_DIR/case1.rollback.out"; then
  :
else
  failed+=("case_rollback_success")
fi

# case2: rollback failure branch (remove permission denied)
TARGET_FAIL="$OUT_DIR/fail-target"
mkdir -p "$TARGET_FAIL"
echo "x" > "$TARGET_FAIL/.zc_installed"
chmod 500 "$TARGET_FAIL"
if bash "$RUNNER" rollback --target-dir "$TARGET_FAIL" > "$OUT_DIR/case2.rollback.out" 2>&1; then
  failed+=("case_rollback_fail_expected")
else
  if ! grep -q 'INSTALL_RESULT=FAIL' "$OUT_DIR/case2.rollback.out" \
    || ! grep -q 'INSTALL_FAILED_STEP=' "$OUT_DIR/case2.rollback.out" \
    || ! grep -q 'INSTALL_NEXT_STEP=' "$OUT_DIR/case2.rollback.out"; then
    failed+=("case_rollback_fail_fields")
  fi
fi
chmod 700 "$TARGET_FAIL" || true
rm -rf "$TARGET_FAIL" || true

result="PASS"
[[ ${#failed[@]} -eq 0 ]] || result="FAIL"

report="$OUT_DIR/summary.json"
printf '{\n  "result":"%s",\n  "failed_cases":["%s"],\n  "evidence_dir":"%s"\n}\n' \
  "$result" "$(IFS='","'; echo "${failed[*]:-}")" "$OUT_DIR" > "$report"

echo "INSTALL_RESULT=$result"
echo "INSTALL_ACTION=rollback-regression"
echo "INSTALL_REPORT=$report"
echo "INSTALL_FAILED_STEP=$(IFS=,; echo "${failed[*]:-}")"
if [[ "$result" == "PASS" ]]; then
  echo "INSTALL_NEXT_STEP=none"
else
  echo "INSTALL_NEXT_STEP=inspect rollback regression outputs under $OUT_DIR"
fi
echo "INSTALL_SUMMARY=rollback regression result=$result failed=${failed[*]:-none}"

echo "ROLLBACK_REGRESSION_RESULT=$result"
echo "ROLLBACK_REGRESSION_REPORT=$report"

[[ "$result" == "PASS" ]]
