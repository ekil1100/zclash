#!/usr/bin/env bash
set -euo pipefail

# Unified single entry for migrator regression gate.
# Steps (fail-fast):
# 1) verify-samples
# 2) summarize-results
# 3) schema check
# 4) compat parity check
# 5) run-regression (fail-fast + human summary)

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="$ROOT_DIR/tools/config-migrator"

fail() {
  local stage="$1"
  echo "MIGRATOR_ALL_RESULT=FAIL"
  echo "MIGRATOR_ALL_FAILED_STAGE=$stage"
  exit 1
}

bash "$BASE/verify-samples.sh" >/dev/null || fail "verify-samples"
bash "$BASE/summarize-results.sh" >/dev/null || fail "summarize-results"
bash "$BASE/validate-summary-schema.sh" >/dev/null || fail "schema-check"
bash "$BASE/check-compat-parity.sh" >/dev/null || fail "compat-parity"

if bash "$BASE/run-regression.sh"; then
  echo "MIGRATOR_ALL_RESULT=PASS"
  echo "MIGRATOR_ALL_FAILED_STAGE="
  echo "MIGRATOR_ALL_REPORT=tools/config-migrator/reports/samples-summary.json"
  exit 0
else
  echo "MIGRATOR_ALL_RESULT=FAIL"
  echo "MIGRATOR_ALL_FAILED_STAGE=run-regression"
  echo "MIGRATOR_ALL_REPORT=tools/config-migrator/reports/samples-summary.json"
  exit 1
fi
