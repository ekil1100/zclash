#!/usr/bin/env bash
set -euo pipefail

# Unified regression entry for first migrator rules (R1/R2)
# Offline reproducible command:
#   bash tools/config-migrator/run-regression.sh

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="$ROOT_DIR/tools/config-migrator"
REPORT_DIR="$BASE/reports"
mkdir -p "$REPORT_DIR"

failed_rules=()
results=()

# R1 validation (PORT_TYPE_INT)
if bash "$BASE/verify-r1.sh" >/dev/null 2>&1; then
  results+=("{\"sample_id\":\"R1_PORT_TYPE_INT\",\"input\":\"tools/config-migrator/examples/r1-port-string.yaml\",\"result\":\"PASS\",\"diff\":\"port/socks-port/mixed-port string->int\",\"hint\":\"autofix applied\"}")
else
  failed_rules+=("PORT_TYPE_INT")
  results+=("{\"sample_id\":\"R1_PORT_TYPE_INT\",\"input\":\"tools/config-migrator/examples/r1-port-string.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"verify-r1 failed\"}")
fi

# R2 validation (LOG_LEVEL_ENUM)
R2_OUT="$REPORT_DIR/r2-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/sample-2.yaml" > "$R2_OUT" 2>/dev/null || true; then
  if grep -q '"rule":"LOG_LEVEL_ENUM"' "$R2_OUT" && grep -q '"fixable":false' "$R2_OUT" && grep -q '"suggested":"info"' "$R2_OUT"; then
    results+=("{\"sample_id\":\"R2_LOG_LEVEL_ENUM\",\"input\":\"tools/config-migrator/examples/sample-2.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"invalid log-level detected with suggested=info\"}")
  else
    failed_rules+=("LOG_LEVEL_ENUM")
    results+=("{\"sample_id\":\"R2_LOG_LEVEL_ENUM\",\"input\":\"tools/config-migrator/examples/sample-2.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected LOG_LEVEL_ENUM error with suggested=info\"}")
  fi
else
  failed_rules+=("LOG_LEVEL_ENUM")
  results+=("{\"sample_id\":\"R2_LOG_LEVEL_ENUM\",\"input\":\"tools/config-migrator/examples/sample-2.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"lint command failed\"}")
fi

pass_count=0
for r in "${results[@]}"; do
  if echo "$r" | grep -q '"result":"PASS"'; then
    pass_count=$((pass_count+1))
  fi
done
fail_count=$(( ${#results[@]} - pass_count ))
status="PASS"
if [[ ${#failed_rules[@]} -gt 0 ]]; then
  status="FAIL"
fi

joined_results=$(IFS=,; echo "${results[*]}")
failed_items="[]"
if [[ ${#failed_rules[@]} -gt 0 ]]; then
  entries=()
  for rule in "${failed_rules[@]}"; do
    entries+=("{\"sample_id\":\"$rule\",\"hint\":\"rule regression failed\"}")
  done
  failed_items="[$(IFS=,; echo "${entries[*]}")]"
fi

OUT_SUMMARY="$REPORT_DIR/samples-summary.json"
cat > "$OUT_SUMMARY" <<EOF
{
  "run_id": "migrator-regression-$(date +%s)",
  "status": "$status",
  "pass_count": $pass_count,
  "fail_count": $fail_count,
  "failed_items": $failed_items,
  "results": [
    $joined_results
  ]
}
EOF

if [[ "$status" == "PASS" ]]; then
  echo "MIGRATOR_REGRESSION_RESULT=PASS"
  echo "MIGRATOR_REGRESSION_FAILED_RULES=[]"
  echo "MIGRATOR_REGRESSION_REPORT=tools/config-migrator/reports/samples-summary.json"
  exit 0
else
  echo "MIGRATOR_REGRESSION_RESULT=FAIL"
  echo "MIGRATOR_REGRESSION_FAILED_RULES=$(IFS=,; echo "${failed_rules[*]}")"
  echo "MIGRATOR_REGRESSION_REPORT=tools/config-migrator/reports/samples-summary.json"
  exit 1
fi
