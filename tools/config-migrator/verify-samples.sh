#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="$ROOT_DIR/tools/config-migrator"
RUN="$BASE/run.sh"
EXAMPLES="$BASE/examples"
REPORTS="$BASE/reports"
mkdir -p "$REPORTS"

run_one() {
  local name="$1"
  local input="$EXAMPLES/$name.yaml"
  local lint_out="$REPORTS/$name.lint.json"
  local fix_out="$REPORTS/$name.autofix.json"

  local status="PASS"
  local reason="ok"

  if ! bash "$RUN" lint "$input" > "$lint_out"; then
    status="FAIL"
    reason="lint_command_failed"
  fi

  if [[ "$status" == "PASS" ]]; then
    if ! grep -q '"mode":"lint"' "$lint_out" || ! grep -q '"issues"' "$lint_out"; then
      status="FAIL"
      reason="lint_output_contract_mismatch"
    fi
  fi

  if [[ "$status" == "PASS" ]]; then
    if ! bash "$RUN" autofix "$input" "$REPORTS/$name.fixed.yaml" > "$fix_out"; then
      status="FAIL"
      reason="autofix_command_failed"
    fi
  fi

  if [[ "$status" == "PASS" ]]; then
    if ! grep -q '"mode":"autofix"' "$fix_out" || ! grep -q '"fixed"' "$fix_out"; then
      status="FAIL"
      reason="autofix_output_contract_mismatch"
    fi
  fi

  cat <<EOF
    {
      "sample": "$name",
      "input": "tools/config-migrator/examples/$name.yaml",
      "lint_output": "tools/config-migrator/reports/$name.lint.json",
      "autofix_output": "tools/config-migrator/reports/$name.autofix.json",
      "status": "$status",
      "reason": "$reason"
    }
EOF
}

s1="$(run_one sample-1)"
s2="$(run_one sample-2)"
s3="$(run_one sample-3)"

cat > "$REPORTS/samples-report.json" <<EOF
{
  "run_id": "migrator-samples-$(date +%s)",
  "status": "PASS",
  "results": [
$s1,
$s2,
$s3
  ]
}
EOF

echo "MIGRATOR_SAMPLES_RESULT=PASS"
echo "MIGRATOR_SAMPLES_REPORT=tools/config-migrator/reports/samples-report.json"
