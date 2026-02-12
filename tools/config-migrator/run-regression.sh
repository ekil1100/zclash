#!/usr/bin/env bash
set -euo pipefail

# Unified regression entry for first migrator rules (R1/R2)
# Offline reproducible command:
#   bash tools/config-migrator/run-regression.sh

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="$ROOT_DIR/tools/config-migrator"
REPORT_DIR="$BASE/reports"
mkdir -p "$REPORT_DIR"

failed_rules=()
failed_samples=()
results=()

# R1 validation (PORT_TYPE_INT)
if bash "$BASE/verify-r1.sh" >/dev/null 2>&1; then
  results+=("{\"sample_id\":\"R1_PORT_TYPE_INT\",\"input\":\"tools/config-migrator/examples/r1-port-string.yaml\",\"result\":\"PASS\",\"diff\":\"port/socks-port/mixed-port string->int\",\"hint\":\"autofix applied\"}")
else
  failed_rules+=("PORT_TYPE_INT")
  failed_samples+=("R1_PORT_TYPE_INT")
  results+=("{\"sample_id\":\"R1_PORT_TYPE_INT\",\"input\":\"tools/config-migrator/examples/r1-port-string.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"verify-r1 failed\"}")
fi

# R2 validation (LOG_LEVEL_ENUM)
R2_OUT="$REPORT_DIR/r2-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/sample-2.yaml" > "$R2_OUT" 2>/dev/null || true; then
  if grep -q '"rule":"LOG_LEVEL_ENUM"' "$R2_OUT" && grep -q '"fixable":false' "$R2_OUT" && grep -q '"suggested":"info"' "$R2_OUT"; then
    results+=("{\"sample_id\":\"R2_LOG_LEVEL_ENUM\",\"input\":\"tools/config-migrator/examples/sample-2.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"invalid log-level detected with suggested=info\"}")
  else
    failed_rules+=("LOG_LEVEL_ENUM")
    failed_samples+=("R2_LOG_LEVEL_ENUM")
    results+=("{\"sample_id\":\"R2_LOG_LEVEL_ENUM\",\"input\":\"tools/config-migrator/examples/sample-2.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected LOG_LEVEL_ENUM error with suggested=info\"}")
  fi
else
  failed_rules+=("LOG_LEVEL_ENUM")
  failed_samples+=("R2_LOG_LEVEL_ENUM")
  results+=("{\"sample_id\":\"R2_LOG_LEVEL_ENUM\",\"input\":\"tools/config-migrator/examples/sample-2.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"lint command failed\"}")
fi

# R3 validation (PROXY_GROUP_TYPE_CHECK)
R3_OUT="$REPORT_DIR/r3-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/r3-proxy-group-type.yaml" > "$R3_OUT" 2>/dev/null || true; then
  if grep -q '"rule":"PROXY_GROUP_TYPE_CHECK"' "$R3_OUT" && grep -q '"fixable":false' "$R3_OUT"; then
    results+=("{\"sample_id\":\"R3_PROXY_GROUP_TYPE_CHECK\",\"input\":\"tools/config-migrator/examples/r3-proxy-group-type.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"invalid proxy group type detected\"}")
  else
    failed_rules+=("PROXY_GROUP_TYPE_CHECK")
    failed_samples+=("R3_PROXY_GROUP_TYPE_CHECK")
    results+=("{\"sample_id\":\"R3_PROXY_GROUP_TYPE_CHECK\",\"input\":\"tools/config-migrator/examples/r3-proxy-group-type.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected PROXY_GROUP_TYPE_CHECK error\"}")
  fi
else
  failed_rules+=("PROXY_GROUP_TYPE_CHECK")
  failed_samples+=("R3_PROXY_GROUP_TYPE_CHECK")
  results+=("{\"sample_id\":\"R3_PROXY_GROUP_TYPE_CHECK\",\"input\":\"tools/config-migrator/examples/r3-proxy-group-type.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"lint command failed\"}")
fi

# R4 validation (DNS_FIELD_CHECK)
R4_OUT="$REPORT_DIR/r4-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/r4-dns-fields.yaml" > "$R4_OUT" 2>/dev/null || true; then
  r4_ok=true
  # Must detect: dns.enable missing (warn), dns.nameserver empty (error), enhanced-mode (warn)
  grep -q '"rule":"DNS_FIELD_CHECK"' "$R4_OUT" || r4_ok=false
  grep -q '"path":"dns.enable"' "$R4_OUT" || r4_ok=false
  grep -q '"path":"dns.nameserver"' "$R4_OUT" || r4_ok=false
  grep -q '"path":"dns.enhanced-mode"' "$R4_OUT" || r4_ok=false
  if [[ "$r4_ok" == "true" ]]; then
    results+=("{\"sample_id\":\"R4_DNS_FIELD_CHECK\",\"input\":\"tools/config-migrator/examples/r4-dns-fields.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"dns field issues detected\"}")
  else
    failed_rules+=("DNS_FIELD_CHECK")
    failed_samples+=("R4_DNS_FIELD_CHECK")
    results+=("{\"sample_id\":\"R4_DNS_FIELD_CHECK\",\"input\":\"tools/config-migrator/examples/r4-dns-fields.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected DNS_FIELD_CHECK issues\"}")
  fi
else
  failed_rules+=("DNS_FIELD_CHECK")
  failed_samples+=("R4_DNS_FIELD_CHECK")
  results+=("{\"sample_id\":\"R4_DNS_FIELD_CHECK\",\"input\":\"tools/config-migrator/examples/r4-dns-fields.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"lint command failed\"}")
fi

# R5 validation (DNS_NAMESERVER_FORMAT)
R5_OUT="$REPORT_DIR/r5-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/r5-dns-nameserver-format.yaml" > "$R5_OUT" 2>/dev/null; then
  if grep -q '"rule":"DNS_NAMESERVER_FORMAT"' "$R5_OUT"; then
    results+=("{\"sample_id\":\"R5_DNS_NAMESERVER_FORMAT\",\"input\":\"tools/config-migrator/examples/r5-dns-nameserver-format.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"plain IP detected\"}")
  else
    failed_rules+=("DNS_NAMESERVER_FORMAT")
    failed_samples+=("R5_DNS_NAMESERVER_FORMAT")
    results+=("{\"sample_id\":\"R5_DNS_NAMESERVER_FORMAT\",\"input\":\"tools/config-migrator/examples/r5-dns-nameserver-format.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected DNS_NAMESERVER_FORMAT warn\"}")
  fi
else
  # lint may exit 0 (only warns), check output
  if grep -q '"rule":"DNS_NAMESERVER_FORMAT"' "$R5_OUT" 2>/dev/null; then
    results+=("{\"sample_id\":\"R5_DNS_NAMESERVER_FORMAT\",\"input\":\"tools/config-migrator/examples/r5-dns-nameserver-format.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"plain IP detected\"}")
  else
    failed_rules+=("DNS_NAMESERVER_FORMAT")
    failed_samples+=("R5_DNS_NAMESERVER_FORMAT")
    results+=("{\"sample_id\":\"R5_DNS_NAMESERVER_FORMAT\",\"input\":\"tools/config-migrator/examples/r5-dns-nameserver-format.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected DNS_NAMESERVER_FORMAT warn\"}")
  fi
fi

# R6 validation (PROXY_GROUP_EMPTY_PROXIES)
R6_OUT="$REPORT_DIR/r6-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/r6-proxy-group-empty.yaml" > "$R6_OUT" 2>/dev/null || true; then
  if grep -q '"rule":"PROXY_GROUP_EMPTY_PROXIES"' "$R6_OUT"; then
    results+=("{\"sample_id\":\"R6_PROXY_GROUP_EMPTY_PROXIES\",\"input\":\"tools/config-migrator/examples/r6-proxy-group-empty.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"empty proxies detected\"}")
  else
    failed_rules+=("PROXY_GROUP_EMPTY_PROXIES")
    failed_samples+=("R6_PROXY_GROUP_EMPTY_PROXIES")
    results+=("{\"sample_id\":\"R6_PROXY_GROUP_EMPTY_PROXIES\",\"input\":\"tools/config-migrator/examples/r6-proxy-group-empty.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected PROXY_GROUP_EMPTY_PROXIES error\"}")
  fi
else
  failed_rules+=("PROXY_GROUP_EMPTY_PROXIES")
  failed_samples+=("R6_PROXY_GROUP_EMPTY_PROXIES")
  results+=("{\"sample_id\":\"R6_PROXY_GROUP_EMPTY_PROXIES\",\"input\":\"tools/config-migrator/examples/r6-proxy-group-empty.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"lint command failed\"}")
fi

# R7 validation (TUN_ENABLE_CHECK)
R7_OUT="$REPORT_DIR/r7-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/r7-tun-enable.yaml" > "$R7_OUT" 2>/dev/null; then
  if grep -q '"rule":"TUN_ENABLE_CHECK"' "$R7_OUT"; then
    results+=("{\"sample_id\":\"R7_TUN_ENABLE_CHECK\",\"input\":\"tools/config-migrator/examples/r7-tun-enable.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"tun.enable detected\"}")
  else
    failed_rules+=("TUN_ENABLE_CHECK")
    failed_samples+=("R7_TUN_ENABLE_CHECK")
    results+=("{\"sample_id\":\"R7_TUN_ENABLE_CHECK\",\"input\":\"tools/config-migrator/examples/r7-tun-enable.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected TUN_ENABLE_CHECK warn\"}")
  fi
else
  if grep -q '"rule":"TUN_ENABLE_CHECK"' "$R7_OUT" 2>/dev/null; then
    results+=("{\"sample_id\":\"R7_TUN_ENABLE_CHECK\",\"input\":\"tools/config-migrator/examples/r7-tun-enable.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"tun.enable detected\"}")
  else
    failed_rules+=("TUN_ENABLE_CHECK")
    failed_samples+=("R7_TUN_ENABLE_CHECK")
    results+=("{\"sample_id\":\"R7_TUN_ENABLE_CHECK\",\"input\":\"tools/config-migrator/examples/r7-tun-enable.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected TUN_ENABLE_CHECK warn\"}")
  fi
fi

# R8 validation (EXTERNAL_CONTROLLER_FORMAT)
R8_OUT="$REPORT_DIR/r8-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/r8-external-controller.yaml" > "$R8_OUT" 2>/dev/null; then
  if grep -q '"rule":"EXTERNAL_CONTROLLER_FORMAT"' "$R8_OUT"; then
    results+=("{\"sample_id\":\"R8_EXTERNAL_CONTROLLER_FORMAT\",\"input\":\"tools/config-migrator/examples/r8-external-controller.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"bad format detected\"}")
  else
    failed_rules+=("EXTERNAL_CONTROLLER_FORMAT")
    failed_samples+=("R8_EXTERNAL_CONTROLLER_FORMAT")
    results+=("{\"sample_id\":\"R8_EXTERNAL_CONTROLLER_FORMAT\",\"input\":\"tools/config-migrator/examples/r8-external-controller.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected EXTERNAL_CONTROLLER_FORMAT warn\"}")
  fi
else
  if grep -q '"rule":"EXTERNAL_CONTROLLER_FORMAT"' "$R8_OUT" 2>/dev/null; then
    results+=("{\"sample_id\":\"R8_EXTERNAL_CONTROLLER_FORMAT\",\"input\":\"tools/config-migrator/examples/r8-external-controller.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"bad format detected\"}")
  else
    failed_rules+=("EXTERNAL_CONTROLLER_FORMAT")
    failed_samples+=("R8_EXTERNAL_CONTROLLER_FORMAT")
    results+=("{\"sample_id\":\"R8_EXTERNAL_CONTROLLER_FORMAT\",\"input\":\"tools/config-migrator/examples/r8-external-controller.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected EXTERNAL_CONTROLLER_FORMAT warn\"}")
  fi
fi

# R9 validation (ALLOW_LAN_BIND_CONFLICT)
R9_OUT="$REPORT_DIR/r9-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/r9-allow-lan-bind.yaml" > "$R9_OUT" 2>/dev/null; then
  if grep -q '"rule":"ALLOW_LAN_BIND_CONFLICT"' "$R9_OUT"; then
    results+=("{\"sample_id\":\"R9_ALLOW_LAN_BIND_CONFLICT\",\"input\":\"tools/config-migrator/examples/r9-allow-lan-bind.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"conflict detected\"}")
  else
    failed_rules+=("ALLOW_LAN_BIND_CONFLICT")
    failed_samples+=("R9_ALLOW_LAN_BIND_CONFLICT")
    results+=("{\"sample_id\":\"R9_ALLOW_LAN_BIND_CONFLICT\",\"input\":\"tools/config-migrator/examples/r9-allow-lan-bind.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected ALLOW_LAN_BIND_CONFLICT warn\"}")
  fi
else
  if grep -q '"rule":"ALLOW_LAN_BIND_CONFLICT"' "$R9_OUT" 2>/dev/null; then
    results+=("{\"sample_id\":\"R9_ALLOW_LAN_BIND_CONFLICT\",\"input\":\"tools/config-migrator/examples/r9-allow-lan-bind.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"conflict detected\"}")
  else
    failed_rules+=("ALLOW_LAN_BIND_CONFLICT")
    failed_samples+=("R9_ALLOW_LAN_BIND_CONFLICT")
    results+=("{\"sample_id\":\"R9_ALLOW_LAN_BIND_CONFLICT\",\"input\":\"tools/config-migrator/examples/r9-allow-lan-bind.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected ALLOW_LAN_BIND_CONFLICT warn\"}")
  fi
fi

# R10 validation (RULE_PROVIDER_REF_CHECK)
R10_OUT="$REPORT_DIR/r10-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/r10-rule-provider-ref.yaml" > "$R10_OUT" 2>/dev/null || true; then
  if grep -q '"rule":"RULE_PROVIDER_REF_CHECK"' "$R10_OUT" && grep -q 'missing-provider' "$R10_OUT"; then
    results+=("{\"sample_id\":\"R10_RULE_PROVIDER_REF_CHECK\",\"input\":\"tools/config-migrator/examples/r10-rule-provider-ref.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"undefined provider detected\"}")
  else
    failed_rules+=("RULE_PROVIDER_REF_CHECK")
    failed_samples+=("R10_RULE_PROVIDER_REF_CHECK")
    results+=("{\"sample_id\":\"R10_RULE_PROVIDER_REF_CHECK\",\"input\":\"tools/config-migrator/examples/r10-rule-provider-ref.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected RULE_PROVIDER_REF_CHECK error\"}")
  fi
fi

# R11 validation (PROXY_NODE_FIELDS_CHECK)
R11_OUT="$REPORT_DIR/r11-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/r11-proxy-fields.yaml" > "$R11_OUT" 2>/dev/null || true; then
  if grep -q '"rule":"PROXY_NODE_FIELDS_CHECK"' "$R11_OUT"; then
    results+=("{\"sample_id\":\"R11_PROXY_NODE_FIELDS_CHECK\",\"input\":\"tools/config-migrator/examples/r11-proxy-fields.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"missing fields detected\"}")
  else
    failed_rules+=("PROXY_NODE_FIELDS_CHECK")
    failed_samples+=("R11_PROXY_NODE_FIELDS_CHECK")
    results+=("{\"sample_id\":\"R11_PROXY_NODE_FIELDS_CHECK\",\"input\":\"tools/config-migrator/examples/r11-proxy-fields.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected PROXY_NODE_FIELDS_CHECK error\"}")
  fi
fi

# R12 validation (SS_CIPHER_ENUM_CHECK)
R12_OUT="$REPORT_DIR/r12-regression.lint.json"
if bash "$BASE/run.sh" lint "$BASE/examples/r12-cipher-enum.yaml" > "$R12_OUT" 2>/dev/null || true; then
  if grep -q '"rule":"SS_CIPHER_ENUM_CHECK"' "$R12_OUT" && grep -q 'aes-256-cbc' "$R12_OUT"; then
    results+=("{\"sample_id\":\"R12_SS_CIPHER_ENUM_CHECK\",\"input\":\"tools/config-migrator/examples/r12-cipher-enum.yaml\",\"result\":\"PASS\",\"diff\":\"\",\"hint\":\"unsupported cipher detected\"}")
  else
    failed_rules+=("SS_CIPHER_ENUM_CHECK")
    failed_samples+=("R12_SS_CIPHER_ENUM_CHECK")
    results+=("{\"sample_id\":\"R12_SS_CIPHER_ENUM_CHECK\",\"input\":\"tools/config-migrator/examples/r12-cipher-enum.yaml\",\"result\":\"FAIL\",\"diff\":\"\",\"hint\":\"expected SS_CIPHER_ENUM_CHECK error\"}")
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
if [[ ${#failed_rules[@]} -gt 0 ]]; then
  status="FAIL"
fi

joined_results=$(IFS=,; echo "${results[*]}")
failed_items="[]"
if [[ ${#failed_rules[@]} -gt 0 ]]; then
  entries=()
  for rule in "${failed_rules[@]}"; do
    entries+=("{\"sample_id\":\"$rule\",\"hint\":\"rule regression failed\"}")
  done
  failed_items="[$(IFS=,; echo "${entries[*]}")]"
fi

OUT_SUMMARY="$REPORT_DIR/samples-summary.json"
cat > "$OUT_SUMMARY" <<EOF
{
  "run_id": "migrator-regression-$(date +%s)",
  "status": "$status",
  "pass_count": $pass_count,
  "fail_count": $fail_count,
  "failed_items": $failed_items,
  "results": [
    $joined_results
  ]
}
EOF

total_count=${#results[@]}

if [[ "$status" == "PASS" ]]; then
  echo "MIGRATOR_REGRESSION_RESULT=PASS"
  echo "MIGRATOR_REGRESSION_FAILED_RULES=[]"
  echo "MIGRATOR_REGRESSION_FAILED_SAMPLES=[]"
  echo "MIGRATOR_REGRESSION_REPORT=tools/config-migrator/reports/samples-summary.json"
  echo "MIGRATOR_REGRESSION_SUMMARY=PASS total=${total_count} failed_rules=0 failed_samples=0"
  exit 0
else
  echo "MIGRATOR_REGRESSION_RESULT=FAIL"
  echo "MIGRATOR_REGRESSION_FAILED_RULES=$(IFS=,; echo "${failed_rules[*]}")"
  echo "MIGRATOR_REGRESSION_FAILED_SAMPLES=$(IFS=,; echo "${failed_samples[*]}")"
  echo "MIGRATOR_REGRESSION_REPORT=tools/config-migrator/reports/samples-summary.json"
  echo "MIGRATOR_REGRESSION_SUMMARY=FAIL total=${total_count} failed_rules=$(IFS=,; echo "${failed_rules[*]}") failed_samples=$(IFS=,; echo "${failed_samples[*]}")"
  # fail-fast gate: any failed rule returns non-zero
  exit 1
fi
