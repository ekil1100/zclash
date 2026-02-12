#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT_DIR/scripts/install/oc-run.sh"
OUT_DIR="/tmp/zc-install-path-matrix"
mkdir -p "$OUT_DIR"

results=()
failed=()
failed_hints=()

record() {
  local id="$1" result="$2" sample="$3" hint="${4:-}"
  results+=("{\"sample_id\":\"$id\",\"result\":\"$result\",\"sample\":\"$sample\",\"hint\":\"$hint\"}")
  if [[ "$result" != "PASS" ]]; then
    failed+=("$id")
    failed_hints+=("$id:$hint")
  fi
}

run_case() {
  local id="$1" target="$2" hint_on_fail="$3"
  local out="$OUT_DIR/$id.out"
  if bash "$RUNNER" install --target-dir "$target" > "$out" 2>&1 \
    && grep -q 'INSTALL_RESULT=PASS' "$out" \
    && bash "$RUNNER" verify --target-dir "$target" >> "$out" 2>&1 \
    && grep -q 'INSTALL_ACTION=verify' "$out"; then
    record "$id" "PASS" "$target" "none"
  else
    if grep -q 'INSTALL_FAILED_STEP=' "$out" && grep -q 'INSTALL_NEXT_STEP=' "$out"; then
      record "$id" "FAIL" "$target" "$hint_on_fail"
    else
      record "$id" "FAIL" "$target(no-machine-fields)" "failure missing machine fields: check runner output contract"
    fi
  fi
}

# normal platform/path style combinations
run_case "case_macos_usr_local_bin" "/tmp/zc-matrix/usr-local-bin" "检查目录权限或改用 /tmp 路径"
run_case "case_linux_user_local_bin" "$HOME/.local/bin/zc-matrix" "确认 HOME 可写并重试"
run_case "case_custom_workspace_bin" "/tmp/zc-matrix/custom-bin" "检查自定义路径是否可写"

run_expected_fail_case() {
  local id="$1" target="$2" hint="$3"
  local out="$OUT_DIR/$id.out"
  if bash "$RUNNER" install --target-dir "$target" > "$out" 2>&1; then
    record "$id" "FAIL" "$target" "预期失败但实际成功，请检查用例设计"
  else
    if grep -q 'INSTALL_RESULT=FAIL' "$out" && grep -q 'INSTALL_FAILED_STEP=' "$out" && grep -q 'INSTALL_NEXT_STEP=' "$out"; then
      record "$id" "PASS" "$target" "$hint"
    else
      record "$id" "FAIL" "$target" "失败缺少机读字段，请修复输出契约"
    fi
  fi
}

# abnormal path: parent is a file (path conflict, expected fail)
CONFLICT_PARENT="$OUT_DIR/conflict-parent"
echo "file" > "$CONFLICT_PARENT"
run_expected_fail_case "case_abnormal_path_conflict" "$CONFLICT_PARENT/subdir" "目标路径与文件冲突：换一个目录路径再试"

# existing install overwrite path
EXISTING_TARGET="/tmp/zc-matrix/existing-bin"
OUT_EXIST1="$OUT_DIR/case_existing_overwrite.1.out"
OUT_EXIST2="$OUT_DIR/case_existing_overwrite.2.out"
bash "$RUNNER" install --target-dir "$EXISTING_TARGET" > "$OUT_EXIST1" 2>&1 || true
if bash "$RUNNER" install --target-dir "$EXISTING_TARGET" > "$OUT_EXIST2" 2>&1 \
  && grep -q 'INSTALL_RESULT=PASS' "$OUT_EXIST2" \
  && bash "$RUNNER" verify --target-dir "$EXISTING_TARGET" >> "$OUT_EXIST2" 2>&1; then
  record "case_existing_install_overwrite" "PASS" "$EXISTING_TARGET" "none"
else
  record "case_existing_install_overwrite" "FAIL" "$EXISTING_TARGET" "已有安装覆盖失败：先 rollback 再 install"
fi

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
echo "INSTALL_MATRIX_FAILED_HINTS=$(IFS='|'; echo "${failed_hints[*]:-}")"

echo "INSTALL_SUMMARY=path matrix $pass/$total passed, failed=${failed[*]:-none}"

[[ "$result" == "PASS" ]]
