#!/usr/bin/env bash
set -euo pipefail

# P4-1.D 占位脚本：只定义入口与 PASS/FAIL 协议，不做真实压测实现。
# 与文档入口保持一致：bash scripts/perf/run-baseline.sh

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/docs/perf/reports"
LATEST_JSON="$REPORT_DIR/latest.json"

mkdir -p "$REPORT_DIR" "$REPORT_DIR/history"

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
RUN_ID="p4d-placeholder-$(date +%s)"

# 阈值占位（后续由真实采样与阈值系统替换）
RULE_EVAL_P95_THRESHOLD="1.0"
DNS_P95_THRESHOLD="80.0"
THROUGHPUT_THRESHOLD="800"

# 占位结果（固定为 pass=true；后续实现将替换为真实测量）
cat > "$LATEST_JSON" <<EOF
{
  "run_id": "$RUN_ID",
  "timestamp": "$TS",
  "mode": "placeholder",
  "metrics": {
    "rule_eval_p95_ms": {"value": 0.0, "threshold": $RULE_EVAL_P95_THRESHOLD, "pass": true},
    "dns_resolve_p95_ms": {"value": 0.0, "threshold": $DNS_P95_THRESHOLD, "pass": true},
    "throughput_rps": {"value": 0, "threshold": $THROUGHPUT_THRESHOLD, "pass": true}
  }
}
EOF

cp "$LATEST_JSON" "$REPORT_DIR/history/$(date +%F)-$RUN_ID.json"

# PASS/FAIL 协议：
# - 输出行必须包含 PERF_REGRESSION_RESULT=PASS|FAIL
# - exit code: 0=PASS, 非0=FAIL
# 当前占位版本固定 PASS。
echo "PERF_REGRESSION_RESULT=PASS"
echo "PERF_REGRESSION_REPORT=$LATEST_JSON"
exit 0
