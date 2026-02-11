#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT_DIR/scripts/install/oc-run.sh"
OUT_DIR="/tmp/zclash-install-path-matrix"
mkdir -p "$OUT_DIR"

results=()
failed=()

record() {
  local id="$1" result="$2" sample="$3"
  results+=("{\"sample_id\":\"$id\",\"result\":\"$result\",\"sample\":\"$sample\"}")
  [[ "$result" == "PASS" ]] || failed+=("$id")
}

run_case() {
  local id="$1" target="$2"
  local out="$OUT_DIR/$id.out"
  if bash "$RUNNER" install --target-dir "$target" > "$out" 2>&1 \
    && grep -q 'INSTALL_RESULT=PASS' "$out" \
    && bash "$RUNNER" verify --target-dir "$target" >> "$out" 2>&1 \
    && grep -q 'INSTALL_ACTION=verify' "$out"; then
    record "$id" "PASS" "$target"
  else
    if grep -q 'INSTALL_FAILED_STEP=' "$out" && grep -q 'INSTALL_NEXT_STEP=' "$out"; then
      record "$id" "FAIL" "$target"
    else
      record "$id" "FAIL" "$target(no-machine-fields)"
    fi
  fi
}

# at least 3 platform/path style combinations
run_case "case_macos_usr_local_bin" "/tmp/zclash-matrix/usr-local-bin"
run_case "case_linux_user_local_bin" "$HOME/.local/bin/zclash-matrix"
run_case "case_custom_workspace_bin" "/tmp/zclash-matrix/custom-bin"

pass=0
for r in "${results[@]}"; do
  echo "$r" | grep -q '"result":"PASS"' && pass=$((pass+1))
done
total=${#results[@]}
fail=$((total-pass))
result="PASS"
[[ $fail -eq 0 ]] || result="FAIL"

report="$OUT_DIR/summary.json"
printf '{\n  "result": "%s",\n  "pass_count": %d,\n  "fail_count": %d,\n  "results": [\n    %s\n  ]\n}\n' "$result" "$pass" "$fail" "$(IFS=,; echo "${results[*]}")" > "$report"

echo "INSTALL_RESULT=$result"
echo "INSTALL_ACTION=path-matrix"
echo "INSTALL_REPORT=$report"
echo "INSTALL_FAILED_STEP=${failed[*]:-}"
if [[ "$result" == "PASS" ]]; then
  echo "INSTALL_NEXT_STEP=none"
else
  echo "INSTALL_NEXT_STEP=inspect INSTALL_MATRIX_FAILED_SAMPLES and rerun target cases"
fi

echo "INSTALL_MATRIX_RESULT=$result"
echo "INSTALL_MATRIX_REPORT=$report"
echo "INSTALL_MATRIX_FAILED_SAMPLES=$(IFS=,; echo "${failed[*]:-}")"

echo "INSTALL_SUMMARY=path matrix $pass/$total passed, failed=${failed[*]:-none}"

[[ "$result" == "PASS" ]]
