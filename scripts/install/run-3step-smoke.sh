#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT_DIR/scripts/install/oc-run.sh"
TARGET_DIR="/tmp/zclash-3step-smoke"
OUT_DIR="/tmp/zclash-3step-smoke-report"
mkdir -p "$OUT_DIR"

steps=(install verify upgrade)
failed=()

bash "$RUNNER" install --target-dir "$TARGET_DIR" > "$OUT_DIR/1-install.out" 2>&1 || failed+=("install")
bash "$RUNNER" verify --target-dir "$TARGET_DIR" > "$OUT_DIR/2-verify.out" 2>&1 || failed+=("verify")
bash "$RUNNER" upgrade --target-dir "$TARGET_DIR" --version v0.2.0 > "$OUT_DIR/3-upgrade.out" 2>&1 || failed+=("upgrade")

total=3
pass=$(( total - ${#failed[@]} ))
result="PASS"
[[ ${#failed[@]} -eq 0 ]] || result="FAIL"

SUMMARY_JSON="$OUT_DIR/summary.json"
printf '{\n  "result":"%s",\n  "pass_count":%d,\n  "total_count":%d,\n  "failed_steps":["%s"],\n  "evidence_dir":"%s"\n}\n' \
  "$result" "$pass" "$total" "$(IFS='","'; echo "${failed[*]:-}")" "$OUT_DIR" > "$SUMMARY_JSON"

# machine fields (runner-aligned + smoke specific)
echo "INSTALL_RESULT=$result"
echo "INSTALL_ACTION=3step-smoke"
echo "INSTALL_REPORT=$SUMMARY_JSON"
echo "INSTALL_FAILED_STEP=$(IFS=,; echo "${failed[*]:-}")"
if [[ "$result" == "PASS" ]]; then
  echo "INSTALL_NEXT_STEP=3步试用通过，可继续执行回归脚本"
else
  echo "INSTALL_NEXT_STEP=查看 $OUT_DIR/*.out 定位失败步骤后重试"
fi

echo "INSTALL_SUMMARY=3-step smoke $pass/$total passed, failed=${failed[*]:-none}"

echo "INSTALL_3STEP_RESULT=$result"
echo "INSTALL_3STEP_REPORT=$SUMMARY_JSON"

test "$result" = "PASS"
