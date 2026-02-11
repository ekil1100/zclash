#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
INPUT="${2:-}"
OUT="${3:-}"

if [[ "$MODE" != "lint" && "$MODE" != "autofix" ]]; then
  echo '{"ok":false,"error":{"code":"MIGRATOR_MODE_INVALID","message":"mode must be lint|autofix","hint":"use: run.sh lint <file>"}}'
  exit 2
fi

if [[ -z "$INPUT" || ! -f "$INPUT" ]]; then
  echo '{"ok":false,"error":{"code":"MIGRATOR_INPUT_MISSING","message":"input file not found","hint":"pass an existing yaml file path"}}'
  exit 2
fi

json_escape() {
  echo "$1" | sed 's/"/\\"/g'
}

collect_issues() {
  local file="$1"
  local issues=()

  # R1: PORT_TYPE_INT - numeric string should be int
  for key in port socks-port mixed-port; do
    if grep -Eq "^[[:space:]]*$key:[[:space:]]*\"[0-9]+\"[[:space:]]*$" "$file"; then
      issues+=("{\"rule\":\"PORT_TYPE_INT\",\"level\":\"warn\",\"path\":\"$key\",\"message\":\"numeric string can be autofixed to int\",\"fixable\":true}")
    fi
  done

  # R3: PROXY_GROUP_TYPE_CHECK
  local valid_types="select|url-test|fallback|load-balance|relay"
  if grep -Eq '^[[:space:]]*-[[:space:]]*name:' "$file" && grep -Eq '^[[:space:]]*type:' "$file"; then
    while IFS= read -r line; do
      raw_type=$(echo "$line" | sed -E 's/^[[:space:]]*type:[[:space:]]*"?([^"[:space:]]+)"?[[:space:]]*$/\1/')
      if [[ -n "$raw_type" ]] && ! echo "$raw_type" | grep -Eq "^($valid_types)$"; then
        issues+=("{\"rule\":\"PROXY_GROUP_TYPE_CHECK\",\"level\":\"error\",\"path\":\"proxy-groups[].type\",\"message\":\"unknown proxy group type: $raw_type\",\"fixable\":false,\"suggested\":\"select\"}")
      fi
    done < <(grep -E '^[[:space:]]*type:[[:space:]]*"?[A-Za-z-]+"?' "$file")
  fi

  # R4: DNS_FIELD_CHECK
  if grep -Eq '^[[:space:]]*dns:' "$file"; then
    # Check dns.enable missing
    if ! grep -Eq '^[[:space:]]+enable:' "$file"; then
      issues+=("{\"rule\":\"DNS_FIELD_CHECK\",\"level\":\"warn\",\"path\":\"dns.enable\",\"message\":\"dns.enable missing, defaults to true\",\"fixable\":false,\"suggested\":\"true\"}")
    fi
    # Check dns.nameserver empty or missing
    if ! grep -Eq '^[[:space:]]+nameserver:' "$file"; then
      issues+=("{\"rule\":\"DNS_FIELD_CHECK\",\"level\":\"error\",\"path\":\"dns.nameserver\",\"message\":\"dns.nameserver missing\",\"fixable\":false}")
    elif grep -A1 'nameserver:' "$file" | grep -Eq '^\s*nameserver:\s*\[\s*\]\s*$'; then
      issues+=("{\"rule\":\"DNS_FIELD_CHECK\",\"level\":\"error\",\"path\":\"dns.nameserver\",\"message\":\"dns.nameserver is empty\",\"fixable\":false}")
    fi
    # Check dns.enhanced-mode (unsupported)
    if grep -Eq '^[[:space:]]+enhanced-mode:' "$file"; then
      issues+=("{\"rule\":\"DNS_FIELD_CHECK\",\"level\":\"warn\",\"path\":\"dns.enhanced-mode\",\"message\":\"zclash ignores enhanced-mode\",\"fixable\":false}")
    fi
  fi

  # R2: LOG_LEVEL_ENUM
  if grep -Eq '^[[:space:]]*log-level:[[:space:]]*"?[A-Za-z-]+"?[[:space:]]*$' "$file"; then
    raw=$(grep -E '^[[:space:]]*log-level:[[:space:]]*"?[A-Za-z-]+"?[[:space:]]*$' "$file" | head -n1 | sed -E 's/^[[:space:]]*log-level:[[:space:]]*"?([^"[:space:]]+)"?[[:space:]]*$/\1/')
    case "$raw" in
      debug|info|warning|error|silent) ;;
      *)
        issues+=("{\"rule\":\"LOG_LEVEL_ENUM\",\"level\":\"error\",\"path\":\"log-level\",\"message\":\"value out of enum\",\"fixable\":false,\"suggested\":\"info\"}")
        ;;
    esac
  fi

  if [[ ${#issues[@]} -eq 0 ]]; then
    echo "[]"
  else
    local joined
    joined=$(IFS=,; echo "${issues[*]}")
    echo "[$joined]"
  fi
}

if [[ "$MODE" == "lint" ]]; then
  issues_json=$(collect_issues "$INPUT")

  if echo "$issues_json" | grep -q '"level":"error"'; then
    ok=false
    hint="fix error-level issues first; for LOG_LEVEL_ENUM use suggested value: info"
  else
    ok=true
    hint="run autofix for fixable issues"
  fi

  echo "{\"ok\":$ok,\"mode\":\"lint\",\"issues\":$issues_json,\"fixed\":0,\"hint\":\"$(json_escape "$hint")\"}"
  if [[ "$ok" == "true" ]]; then
    exit 0
  else
    exit 1
  fi
fi

# autofix mode: apply R1 only (PORT_TYPE_INT)
out_path="${OUT:-$INPUT.bak}"
cp "$INPUT" "$out_path"

fixed=0
for key in port socks-port mixed-port; do
  count=$(grep -Ec "^[[:space:]]*$key:[[:space:]]*\"[0-9]+\"[[:space:]]*$" "$out_path" || true)
  if [[ "$count" -gt 0 ]]; then
    fixed=$((fixed + count))
    sed -E -i.bak "s|^([[:space:]]*$key:[[:space:]]*)\"([0-9]+)\"([[:space:]]*)$|\1\2\3|" "$out_path"
    rm -f "$out_path.bak"
  fi
done

issues_json=$(collect_issues "$out_path")
if echo "$issues_json" | grep -q '"level":"error"'; then
  ok=false
  hint="autofix done for fixable issues; unresolved error-level issues remain"
else
  ok=true
  hint="autofix applied"
fi

echo "{\"ok\":$ok,\"mode\":\"autofix\",\"issues\":$issues_json,\"fixed\":$fixed,\"hint\":\"$(json_escape "$hint")\"}"
if [[ "$ok" == "true" ]]; then
  exit 0
else
  exit 1
fi
