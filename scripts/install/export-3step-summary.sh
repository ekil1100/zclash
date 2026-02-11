#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SMOKE_SCRIPT="$ROOT_DIR/scripts/install/run-3step-smoke.sh"
OUT_DIR="/tmp/zclash-3step-public"
mkdir -p "$OUT_DIR"

SMOKE_OUT="$OUT_DIR/smoke.out"
if bash "$SMOKE_SCRIPT" > "$SMOKE_OUT" 2>&1; then
  result="PASS"
else
  result="FAIL"
fi

report_path="$(grep '^INSTALL_3STEP_REPORT=' "$SMOKE_OUT" | sed 's/^INSTALL_3STEP_REPORT=//')"
summary_line="$(grep '^INSTALL_SUMMARY=' "$SMOKE_OUT" | sed 's/^INSTALL_SUMMARY=//')"
next_step_line="$(grep '^INSTALL_NEXT_STEP=' "$SMOKE_OUT" | sed 's/^INSTALL_NEXT_STEP=//')"
failed_step_line="$(grep '^INSTALL_FAILED_STEP=' "$SMOKE_OUT" | sed 's/^INSTALL_FAILED_STEP=//')"

PUBLIC_SUMMARY="$OUT_DIR/public-summary.txt"
cat > "$PUBLIC_SUMMARY" <<EOF
zclash 安装链路 3 步试用结果（对外版）
- 结果：$result
- 摘要：${summary_line:-N/A}
- 失败步骤：${failed_step_line:-none}
- 建议下一步：${next_step_line:-none}
- 证据：${report_path:-N/A}
EOF

# machine fields
echo "INSTALL_RESULT=$result"
echo "INSTALL_ACTION=3step-public-summary"
echo "INSTALL_REPORT=${report_path:-}"
echo "INSTALL_FAILED_STEP=${failed_step_line:-}"
if [[ "$result" == "PASS" ]]; then
  echo "INSTALL_NEXT_STEP=3步 smoke 通过，可对外发送 public-summary.txt"
else
  echo "INSTALL_NEXT_STEP=3步 smoke 未通过，先按失败提示修复后再发送"
fi
echo "INSTALL_SUMMARY=${summary_line:-3-step summary unavailable}"

echo "INSTALL_PUBLIC_SUMMARY=$PUBLIC_SUMMARY"
echo "INSTALL_PUBLIC_RESULT=$result"
