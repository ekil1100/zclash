#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
required=(INSTALL_RESULT INSTALL_ACTION INSTALL_REPORT INSTALL_FAILED_STEP INSTALL_NEXT_STEP INSTALL_SUMMARY)

check_output() {
  local name="$1"
  local cmd="$2"
  local out="/tmp/schema-${name}.out"
  bash -lc "$cmd" > "$out" 2>&1 || true
  local missing=()
  for k in "${required[@]}"; do
    grep -q "^${k}=" "$out" || missing+=("$k")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$name:${missing[*]}" >> /tmp/schema-diff.list
  fi
}

: > /tmp/schema-diff.list
check_output matrix "bash $ROOT/verify-install-path-matrix.sh"
check_output smoke "bash $ROOT/run-3step-smoke.sh"
check_output public "bash $ROOT/export-3step-summary.sh"

result="PASS"
[[ -s /tmp/schema-diff.list ]] && result="FAIL"

echo "INSTALL_RESULT=$result"
echo "INSTALL_ACTION=schema-consistency"
echo "INSTALL_REPORT=/tmp/schema-diff.list"
if [[ "$result" == "FAIL" ]]; then
  failed_step="$(paste -sd, /tmp/schema-diff.list)"
else
  failed_step=""
fi
echo "INSTALL_FAILED_STEP=$failed_step"
[[ "$result" == "PASS" ]] && echo "INSTALL_NEXT_STEP=none" || echo "INSTALL_NEXT_STEP=补齐缺失字段后重跑；差异见 /tmp/schema-diff.list"
echo "INSTALL_SUMMARY=schema consistency $result"

[[ "$result" == "PASS" ]]
