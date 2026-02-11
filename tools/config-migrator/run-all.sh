#!/usr/bin/env bash
set -euo pipefail

# Unified single entry for migrator regression chain.
# Steps:
# 1) verify-samples
# 2) summarize-results
# 3) run-regression (fail-fast gate + human summary)

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="$ROOT_DIR/tools/config-migrator"

bash "$BASE/verify-samples.sh" >/dev/null
bash "$BASE/summarize-results.sh" >/dev/null

if bash "$BASE/run-regression.sh"; then
  echo "MIGRATOR_ALL_RESULT=PASS"
  exit 0
else
  echo "MIGRATOR_ALL_RESULT=FAIL"
  exit 1
fi
