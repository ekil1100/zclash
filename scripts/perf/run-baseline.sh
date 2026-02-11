#!/usr/bin/env bash
set -euo pipefail

# P4-1 baseline script (minimal executable)
# Contract:
# - write latest.json then archive to history/
# - print PERF_REGRESSION_RESULT=PASS|FAIL
# - print PERF_REGRESSION_REPORT=<path>
# - exit code: 0 PASS, 1 FAIL

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/docs/perf/reports"
LATEST_JSON="$REPORT_DIR/latest.json"
HISTORY_DIR="$REPORT_DIR/history"

mkdir -p "$REPORT_DIR" "$HISTORY_DIR"

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
RUN_ID="p4-baseline-$(date +%s)"

# Thresholds (align with README placeholders)
RULE_EVAL_P95_THRESHOLD="1.0"
DNS_P95_THRESHOLD="80.0"
THROUGHPUT_THRESHOLD="800"
HANDSHAKE_P95_THRESHOLD="120.0"

# Minimal sample values (override by env for local/CI simulation)
RULE_EVAL_P95_VALUE="${RULE_EVAL_P95_VALUE:-0.8}"
DNS_P95_VALUE="${DNS_P95_VALUE:-70.0}"
THROUGHPUT_VALUE="${THROUGHPUT_VALUE:-900}"
HANDSHAKE_P95_VALUE="${HANDSHAKE_P95_VALUE:-90.0}"

pass_rule=true
pass_dns=true
pass_tput=true
pass_hs=true
failed_fields=()

awk -v v="$RULE_EVAL_P95_VALUE" -v t="$RULE_EVAL_P95_THRESHOLD" 'BEGIN{exit (v<=t)?0:1}' || { pass_rule=false; failed_fields+=("rule_eval_p95_ms"); }
awk -v v="$DNS_P95_VALUE" -v t="$DNS_P95_THRESHOLD" 'BEGIN{exit (v<=t)?0:1}' || { pass_dns=false; failed_fields+=("dns_resolve_p95_ms"); }
awk -v v="$THROUGHPUT_VALUE" -v t="$THROUGHPUT_THRESHOLD" 'BEGIN{exit (v>=t)?0:1}' || { pass_tput=false; failed_fields+=("throughput_rps"); }
awk -v v="$HANDSHAKE_P95_VALUE" -v t="$HANDSHAKE_P95_THRESHOLD" 'BEGIN{exit (v<=t)?0:1}' || { pass_hs=false; failed_fields+=("handshake_p95_ms"); }

result="PASS"
exit_code=0
if [[ ${#failed_fields[@]} -gt 0 ]]; then
  result="FAIL"
  exit_code=1
fi

cat > "$LATEST_JSON" <<EOF
{
  "run_id": "$RUN_ID",
  "timestamp": "$TS",
  "mode": "baseline",
  "metrics": {
    "rule_eval_p95_ms": {"value": $RULE_EVAL_P95_VALUE, "threshold": $RULE_EVAL_P95_THRESHOLD, "pass": $pass_rule},
    "dns_resolve_p95_ms": {"value": $DNS_P95_VALUE, "threshold": $DNS_P95_THRESHOLD, "pass": $pass_dns},
    "throughput_rps": {"value": $THROUGHPUT_VALUE, "threshold": $THROUGHPUT_THRESHOLD, "pass": $pass_tput},
    "handshake_p95_ms": {"value": $HANDSHAKE_P95_VALUE, "threshold": $HANDSHAKE_P95_THRESHOLD, "pass": $pass_hs}
  }
}
EOF

cp "$LATEST_JSON" "$HISTORY_DIR/$(date +%F)-$RUN_ID.json"

echo "PERF_REGRESSION_RESULT=$result"
if [[ ${#failed_fields[@]} -gt 0 ]]; then
  echo "PERF_REGRESSION_FAILED_FIELDS=$(IFS=,; echo "${failed_fields[*]}")"
fi
echo "PERF_REGRESSION_REPORT=$LATEST_JSON"
exit "$exit_code"
