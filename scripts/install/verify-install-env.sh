#!/usr/bin/env bash
set -euo pipefail

# Cross-environment minimal verification suite:
# 1) normal user-writable path
# 2) permission denied path (simulated)
# 3) re-install overwrite existing installation

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT_DIR/scripts/install/oc-run.sh"
TMP_ROOT="/tmp/zclash-install-env"
REPORT="$TMP_ROOT/install-env-summary.json"

rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT"

results=()
fails=()

add_result() {
  local id="$1" status="$2" hint="$3"
  results+=("{\"sample_id\":\"$id\",\"result\":\"$status\",\"hint\":\"$hint\"}")
  if [[ "$status" != "PASS" ]]; then
    fails+=("$id")
  fi
}

# case1: normal path
OUT1="$TMP_ROOT/case1.out"
if bash "$RUNNER" install --target-dir "$TMP_ROOT/user-bin" > "$OUT1" 2>&1 && grep -q 'INSTALL_RESULT=PASS' "$OUT1"; then
  add_result "case_normal_path" "PASS" "normal writable path ok"
else
  add_result "case_normal_path" "FAIL" "check target-dir writability"
fi

# case2: permission denied (real non-simulated path)
# try privileged root-owned location first; if writable in current env, fallback to /sys (linux-like readonly)
REAL_DENIED_TARGET="/var/root/zclash-install-test"
if mkdir -p "$REAL_DENIED_TARGET" 2>/dev/null; then
  REAL_DENIED_TARGET="/sys/zclash-install-test"
fi
OUT2="$TMP_ROOT/case2.out"
if bash "$RUNNER" install --target-dir "$REAL_DENIED_TARGET" > "$OUT2" 2>&1; then
  add_result "case_permission_denied_real" "FAIL" "expected permission failure on protected path"
else
  if grep -q 'INSTALL_RESULT=FAIL' "$OUT2" \
    && grep -q 'INSTALL_FAILED_STEP=' "$OUT2" \
    && grep -q 'INSTALL_NEXT_STEP=' "$OUT2"; then
    add_result "case_permission_denied_real" "PASS" "real permission failure produced machine fields"
  else
    add_result "case_permission_denied_real" "FAIL" "missing machine fields on permission failure"
  fi
fi

# case2b: permission denied (simulate by file-as-dir)
FAKE_TARGET="$TMP_ROOT/not-a-dir"
echo "file" > "$FAKE_TARGET"
OUT2B="$TMP_ROOT/case2b.out"
if bash "$RUNNER" install --target-dir "$FAKE_TARGET" > "$OUT2B" 2>&1; then
  add_result "case_permission_denied_simulated" "FAIL" "expected failure for invalid target"
else
  if grep -q 'INSTALL_NEXT_STEP=' "$OUT2B" && grep -q 'INSTALL_FAILED_STEP=' "$OUT2B"; then
    add_result "case_permission_denied_simulated" "PASS" "machine fields + next-step provided"
  else
    add_result "case_permission_denied_simulated" "FAIL" "missing machine fields on failure"
  fi
fi

# case3: existing install overwrite
OUT3A="$TMP_ROOT/case3a.out"
OUT3B="$TMP_ROOT/case3b.out"
bash "$RUNNER" install --target-dir "$TMP_ROOT/existing-bin" > "$OUT3A" 2>&1 || true
if bash "$RUNNER" install --target-dir "$TMP_ROOT/existing-bin" > "$OUT3B" 2>&1 && grep -q 'INSTALL_RESULT=PASS' "$OUT3B"; then
  add_result "case_existing_overwrite" "PASS" "re-install overwrite path ok"
else
  add_result "case_existing_overwrite" "FAIL" "re-install should be idempotent"
fi

# case4: path conflict (target under existing file path)
CONFLICT_PARENT="$TMP_ROOT/conflict-file"
echo "x" > "$CONFLICT_PARENT"
OUT4="$TMP_ROOT/case4.out"
if bash "$RUNNER" install --target-dir "$CONFLICT_PARENT/subdir" > "$OUT4" 2>&1; then
  add_result "case_path_conflict" "FAIL" "expected failure for path conflict"
else
  if grep -q 'INSTALL_FAILED_STEP=' "$OUT4" && grep -q 'INSTALL_NEXT_STEP=' "$OUT4"; then
    add_result "case_path_conflict" "PASS" "path conflict failed with machine-readable next-step"
  else
    add_result "case_path_conflict" "FAIL" "missing failure metadata for path conflict"
  fi
fi

pass_count=0
for r in "${results[@]}"; do
  if echo "$r" | grep -q '"result":"PASS"'; then
    pass_count=$((pass_count+1))
  fi
done
fail_count=$(( ${#results[@]} - pass_count ))
status="PASS"
if [[ "$fail_count" -gt 0 ]]; then
  status="FAIL"
fi

printf '{\n  "run_id": "install-env-%s",\n  "status": "%s",\n  "pass_count": %d,\n  "fail_count": %d,\n  "results": [\n    %s\n  ]\n}\n' "$(date +%s)" "$status" "$pass_count" "$fail_count" "$(IFS=,; echo "${results[*]}")" > "$REPORT"

echo "INSTALL_ENV_REGRESSION_RESULT=$status"
echo "INSTALL_ENV_REGRESSION_REPORT=$REPORT"
echo "INSTALL_ENV_FAILED_SAMPLES=$(IFS=,; echo "${fails[*]:-}")"

if [[ "$status" == "PASS" ]]; then
  exit 0
else
  exit 1
fi
