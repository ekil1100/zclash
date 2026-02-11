#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="$ROOT_DIR/tools/config-migrator"
RUN="$BASE/run.sh"
IN="$BASE/examples/r1-port-string.yaml"
OUT="$BASE/reports/r1-port-string.fixed.yaml"
LINT_BEFORE="$BASE/reports/r1-port-string.lint.before.json"
FIX_OUT="$BASE/reports/r1-port-string.autofix.json"
LINT_AFTER="$BASE/reports/r1-port-string.lint.after.json"

mkdir -p "$BASE/reports"

# lint before: should hit PORT_TYPE_INT
bash "$RUN" lint "$IN" > "$LINT_BEFORE" || true
if ! grep -q '"rule":"PORT_TYPE_INT"' "$LINT_BEFORE"; then
  echo "R1_VERIFY_RESULT=FAIL"
  echo "R1_VERIFY_REASON=PORT_TYPE_INT_not_detected"
  exit 1
fi

# autofix
bash "$RUN" autofix "$IN" "$OUT" > "$FIX_OUT" || true
if ! grep -q '"fixed":3' "$FIX_OUT"; then
  echo "R1_VERIFY_RESULT=FAIL"
  echo "R1_VERIFY_REASON=autofix_fixed_count_unexpected"
  exit 1
fi

# lint after: PORT_TYPE_INT should be gone
bash "$RUN" lint "$OUT" > "$LINT_AFTER" || true
if grep -q '"rule":"PORT_TYPE_INT"' "$LINT_AFTER"; then
  echo "R1_VERIFY_RESULT=FAIL"
  echo "R1_VERIFY_REASON=PORT_TYPE_INT_still_present_after_autofix"
  exit 1
fi

echo "R1_VERIFY_RESULT=PASS"
echo "R1_VERIFY_REPORT=tools/config-migrator/reports/r1-port-string.lint.after.json"
