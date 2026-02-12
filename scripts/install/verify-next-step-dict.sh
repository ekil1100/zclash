#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
RUNNER="$ROOT/oc-run.sh"
OUT="/tmp/zc-next-step-dict"
mkdir -p "$OUT"
fails=()

check_fail() {
  local id="$1" cmd="$2"
  local out="$OUT/$id.out"
  if bash -lc "$cmd" > "$out" 2>&1; then
    fails+=("$id_expected_fail")
  else
    grep -q '^INSTALL_FAILED_STEP=' "$out" || fails+=("$id_missing_failed_step")
    grep -q '^INSTALL_NEXT_STEP=' "$out" || fails+=("$id_missing_next_step")
  fi
}

# 4 failure classes
check_fail permission "bash $RUNNER install --target-dir /var/root/zc-test"
check_fail path "bash $RUNNER install --target-dir ''"
check_fail conflict "echo x > /tmp/zc-conflict-file && bash $RUNNER install --target-dir /tmp/zc-conflict-file/sub"
bash $RUNNER install --target-dir /tmp/zc-next-step-dep > /tmp/zc-next-step-dep.install.out 2>&1 || true
check_fail dependency_missing "bash $RUNNER verify --target-dir /tmp/zc-next-step-dep --require-cmd definitely_missing_cmd_123"

result="PASS"; [[ ${#fails[@]} -eq 0 ]] || result="FAIL"

echo "INSTALL_RESULT=$result"
echo "INSTALL_ACTION=next-step-dict-regression"
echo "INSTALL_REPORT=$OUT"
echo "INSTALL_FAILED_STEP=$(IFS=,; echo "${fails[*]:-}")"
[[ "$result" == "PASS" ]] && echo "INSTALL_NEXT_STEP=none" || echo "INSTALL_NEXT_STEP=补齐缺失词典映射并重跑"
echo "INSTALL_SUMMARY=next-step dict regression result=$result failed=${fails[*]:-none}"

[[ "$result" == "PASS" ]]
