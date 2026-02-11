#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
README="$ROOT_DIR/docs/perf/reports/README.md"
ENTRY="$ROOT_DIR/scripts/perf-regression.sh"
LATEST_JSON="$ROOT_DIR/docs/perf/reports/latest.json"

failures=()

add_failure() {
  failures+=("$1")
}

line_no() {
  local pattern="$1"
  local file="$2"
  local n
  n=$(grep -n "$pattern" "$file" | head -n1 | cut -d: -f1 || true)
  echo "${n:-0}"
}

# 1) README 声明的字段顺序检查
readme_result_line=$(line_no 'PERF_REGRESSION_RESULT=<PASS|FAIL>' "$README")
readme_report_line=$(line_no 'PERF_REGRESSION_REPORT=<path>' "$README")
if [[ "$readme_result_line" -eq 0 || "$readme_report_line" -eq 0 || "$readme_result_line" -ge "$readme_report_line" ]]; then
  add_failure "readme_terminal_field_order"
fi

readme_json_order_ok=true
for key in '"run_id"' '"timestamp"' '"mode"' '"metrics"'; do
  line=$(line_no "$key" "$README")
  [[ "$line" -gt 0 ]] || readme_json_order_ok=false
done
if [[ "$readme_json_order_ok" != true ]]; then
  add_failure "readme_json_field_presence"
fi

# 2) 脚本输出顺序与返回码检查
set +e
output=$(bash "$ENTRY" 2>&1)
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  add_failure "script_exit_code"
fi

result_pos=$(printf '%s\n' "$output" | grep -n '^PERF_REGRESSION_RESULT=' | head -n1 | cut -d: -f1 || true)
report_pos=$(printf '%s\n' "$output" | grep -n '^PERF_REGRESSION_REPORT=' | head -n1 | cut -d: -f1 || true)

if [[ -z "$result_pos" || -z "$report_pos" || "$result_pos" -ge "$report_pos" ]]; then
  add_failure "script_terminal_field_order"
fi

# 3) latest.json 字段顺序检查（与 README 固化顺序一致）
if [[ ! -f "$LATEST_JSON" ]]; then
  add_failure "latest_json_missing"
else
  run_id_line=$(line_no '"run_id"' "$LATEST_JSON")
  ts_line=$(line_no '"timestamp"' "$LATEST_JSON")
  mode_line=$(line_no '"mode"' "$LATEST_JSON")
  metrics_line=$(line_no '"metrics"' "$LATEST_JSON")

  if [[ "$run_id_line" -eq 0 || "$ts_line" -eq 0 || "$mode_line" -eq 0 || "$metrics_line" -eq 0 || "$run_id_line" -ge "$ts_line" || "$ts_line" -ge "$mode_line" || "$mode_line" -ge "$metrics_line" ]]; then
    add_failure "latest_json_top_field_order"
  fi

  m1=$(line_no '"rule_eval_p95_ms"' "$LATEST_JSON")
  m2=$(line_no '"dns_resolve_p95_ms"' "$LATEST_JSON")
  m3=$(line_no '"throughput_rps"' "$LATEST_JSON")
  if [[ "$m1" -eq 0 || "$m2" -eq 0 || "$m3" -eq 0 || "$m1" -ge "$m2" || "$m2" -ge "$m3" ]]; then
    add_failure "latest_json_metrics_field_order"
  fi
fi

if [[ ${#failures[@]} -eq 0 ]]; then
  echo "PERF_README_CONSISTENCY=PASS"
  exit 0
else
  echo "PERF_README_CONSISTENCY=FAIL"
  echo "FAILED_FIELDS=$(IFS=,; echo "${failures[*]}")"
  exit 1
fi
