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

_proxy_issues=()

_check_proxy_fields() {
  local block="$1"
  local pname ptype
  pname=$(echo "$block" | grep -oE 'name:[[:space:]]*"?[^"]*"?' | head -1 | sed -E 's/name:[[:space:]]*"?([^"]*)"?/\1/')
  ptype=$(echo "$block" | grep -oE 'type:[[:space:]]*[a-z]+' | head -1 | sed -E 's/type:[[:space:]]*//')

  # Skip direct/reject - no server/port needed
  [[ "$ptype" == "direct" || "$ptype" == "reject" ]] && return

  if [[ -z "$pname" ]]; then
    _proxy_issues+=("{\"rule\":\"PROXY_NODE_FIELDS_CHECK\",\"level\":\"error\",\"path\":\"proxies[?]\",\"message\":\"proxy node missing 'name' field\",\"fixable\":false}")
  fi
  if [[ -n "$ptype" ]] && ! echo "$block" | grep -Eq 'server:'; then
    _proxy_issues+=("{\"rule\":\"PROXY_NODE_FIELDS_CHECK\",\"level\":\"error\",\"path\":\"proxies[$pname].server\",\"message\":\"proxy '$pname' missing 'server' field\",\"fixable\":false}")
  fi
  if [[ -n "$ptype" ]] && ! echo "$block" | grep -Eq 'port:'; then
    _proxy_issues+=("{\"rule\":\"PROXY_NODE_FIELDS_CHECK\",\"level\":\"error\",\"path\":\"proxies[$pname].port\",\"message\":\"proxy '$pname' missing 'port' field\",\"fixable\":false}")
  fi
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

  # R14: MIXED_PORT_CONFLICT_CHECK
  local has_mixed=false has_port=false has_socks=false
  grep -Eq '^[[:space:]]*mixed-port:' "$file" && has_mixed=true
  grep -Eq '^[[:space:]]*port:' "$file" && has_port=true
  grep -Eq '^[[:space:]]*socks-port:' "$file" && has_socks=true
  if [[ "$has_mixed" == "true" ]] && [[ "$has_port" == "true" || "$has_socks" == "true" ]]; then
    issues+=("{\"rule\":\"MIXED_PORT_CONFLICT_CHECK\",\"level\":\"warn\",\"path\":\"port/socks-port\",\"message\":\"mixed-port is set, port/socks-port will be ignored\",\"fixable\":false,\"suggested\":\"remove port/socks-port when using mixed-port\"}")
  fi

  # R13: VMESS_UUID_FORMAT_CHECK
  local in_vmess=false vmess_name=""
  while IFS= read -r line; do
    if echo "$line" | grep -Eq 'type:[[:space:]]*vmess'; then
      in_vmess=true
      vmess_name=""
    elif [[ "$in_vmess" == "true" ]] && echo "$line" | grep -Eq 'name:'; then
      vmess_name=$(echo "$line" | sed -E 's/.*name:[[:space:]]*"?([^"]*)"?.*/\1/')
    elif [[ "$in_vmess" == "true" ]] && echo "$line" | grep -Eq 'uuid:'; then
      uuid_val=$(echo "$line" | sed -E 's/.*uuid:[[:space:]]*"?([^"]*)"?.*/\1/')
      # UUID v4 pattern: 8-4-4-4-12 hex digits
      if ! echo "$uuid_val" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'; then
        issues+=("{\"rule\":\"VMESS_UUID_FORMAT_CHECK\",\"level\":\"error\",\"path\":\"proxies[$vmess_name].uuid\",\"message\":\"invalid UUID format: $uuid_val\",\"fixable\":false}")
      fi
      in_vmess=false
    elif [[ "$in_vmess" == "true" ]] && echo "$line" | grep -Eq '^[[:space:]]*-[[:space:]]*(name|type|server|port):'; then
      # Next proxy or end of vmess block
      in_vmess=false
    fi
  done < <(grep -E '^[[:space:]]*(name:|type:|uuid:|server:|port:|-[[:space:]]*name:)' "$file")

  # R12: SS_CIPHER_ENUM_CHECK
  local valid_ciphers="aes-128-gcm|aes-192-gcm|aes-256-gcm|aes-128-cfb|aes-192-cfb|aes-256-cfb|chacha20-ietf-poly1305|chacha20-poly1305|rc4-md5|none"
  while IFS= read -r line; do
    cipher_val=$(echo "$line" | sed -E 's/^[[:space:]]*cipher:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
    if [[ -n "$cipher_val" ]] && ! echo "$cipher_val" | grep -Eq "^($valid_ciphers)$"; then
      issues+=("{\"rule\":\"SS_CIPHER_ENUM_CHECK\",\"level\":\"error\",\"path\":\"proxies[].cipher\",\"message\":\"unsupported cipher: $cipher_val\",\"fixable\":false,\"suggested\":\"aes-256-gcm\"}")
    fi
  done < <(grep -E '^[[:space:]]*cipher:' "$file")

  # R11: PROXY_NODE_FIELDS_CHECK
  if grep -Eq '^[[:space:]]*proxies:' "$file"; then
    local proxy_block=""
    local in_proxy=false
    while IFS= read -r line; do
      if echo "$line" | grep -Eq '^[[:space:]]*-[[:space:]]*name:|^[[:space:]]*-[[:space:]]*type:'; then
        # Process previous block
        if [[ -n "$proxy_block" ]]; then
          _check_proxy_fields "$proxy_block"
        fi
        proxy_block="$line"
      elif [[ -n "$proxy_block" ]]; then
        proxy_block="$proxy_block
$line"
      fi
    done < <(awk '/^[[:space:]]*proxies:/{found=1; next} found && /^[^[:space:]]/{exit} found{print}' "$file")
    # Last block
    if [[ -n "$proxy_block" ]]; then
      _check_proxy_fields "$proxy_block"
    fi
  fi

  # Merge proxy field issues
  for pi in "${_proxy_issues[@]:-}"; do
    [[ -n "$pi" ]] && issues+=("$pi")
  done
  _proxy_issues=()

  # R10: RULE_PROVIDER_REF_CHECK
  if grep -Eq '^[[:space:]]*rule-providers:' "$file" && grep -Eq 'RULE-SET,' "$file"; then
    # Collect declared provider names
    local providers=()
    while IFS= read -r line; do
      pname=$(echo "$line" | sed -E 's/^[[:space:]]+([^:]+):[[:space:]]*$/\1/')
      [[ -n "$pname" ]] && providers+=("$pname")
    done < <(awk '/^[[:space:]]*rule-providers:/{found=1; next} found && /^[[:space:]]{2,4}[a-zA-Z]/{print; next} found && /^[^[:space:]]/{exit}' "$file")
    # Check RULE-SET references
    while IFS= read -r line; do
      ref=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*RULE-SET,([^,]+),.*/\1/')
      if [[ -n "$ref" ]]; then
        local found_ref=false
        for p in "${providers[@]:-}"; do
          [[ "$p" == "$ref" ]] && found_ref=true && break
        done
        if [[ "$found_ref" == "false" ]]; then
          issues+=("{\"rule\":\"RULE_PROVIDER_REF_CHECK\",\"level\":\"error\",\"path\":\"rules[RULE-SET,$ref]\",\"message\":\"RULE-SET references undefined provider: $ref\",\"fixable\":false}")
        fi
      fi
    done < <(grep -E '^[[:space:]]*-[[:space:]]*RULE-SET,' "$file")
  fi

  # R9: ALLOW_LAN_BIND_CONFLICT
  if grep -Eq '^[[:space:]]*allow-lan:[[:space:]]*false' "$file"; then
    if grep -Eq '^[[:space:]]*bind-address:' "$file"; then
      bind_val=$(grep -E '^[[:space:]]*bind-address:' "$file" | head -n1 | sed -E 's/^[[:space:]]*bind-address:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
      if [[ "$bind_val" != "127.0.0.1" && "$bind_val" != "localhost" ]]; then
        issues+=("{\"rule\":\"ALLOW_LAN_BIND_CONFLICT\",\"level\":\"warn\",\"path\":\"bind-address\",\"message\":\"allow-lan=false but bind-address=$bind_val (will be overridden to 127.0.0.1)\",\"fixable\":false,\"suggested\":\"127.0.0.1\"}")
      fi
    fi
  fi

  # R8: EXTERNAL_CONTROLLER_FORMAT
  if grep -Eq '^[[:space:]]*external-controller:' "$file"; then
    ec_val=$(grep -E '^[[:space:]]*external-controller:' "$file" | head -n1 | sed -E 's/^[[:space:]]*external-controller:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
    if [[ -n "$ec_val" ]] && ! echo "$ec_val" | grep -Eq '^[^:]+:[0-9]+$'; then
      issues+=("{\"rule\":\"EXTERNAL_CONTROLLER_FORMAT\",\"level\":\"warn\",\"path\":\"external-controller\",\"message\":\"expected host:port format, got: $ec_val\",\"fixable\":false,\"suggested\":\"127.0.0.1:$ec_val\"}")
    fi
  fi

  # R7: TUN_ENABLE_CHECK
  if grep -Eq '^[[:space:]]*tun:' "$file"; then
    if grep -Eq '^[[:space:]]+enable:[[:space:]]*true' "$file"; then
      issues+=("{\"rule\":\"TUN_ENABLE_CHECK\",\"level\":\"warn\",\"path\":\"tun.enable\",\"message\":\"tun mode is not supported by zclash, will be ignored\",\"fixable\":false}")
    elif ! grep -Eq '^[[:space:]]+enable:' "$file"; then
      issues+=("{\"rule\":\"TUN_ENABLE_CHECK\",\"level\":\"info\",\"path\":\"tun.enable\",\"message\":\"tun section present but enable not set, will be ignored\",\"fixable\":false}")
    fi
  fi

  # R6: PROXY_GROUP_EMPTY_PROXIES
  if grep -Eq '^[[:space:]]*-[[:space:]]*name:' "$file" && grep -Eq '^[[:space:]]*proxy-groups:' "$file"; then
    # Detect groups with empty proxies array or missing proxies key
    local in_group=false group_name="" has_proxies=false
    while IFS= read -r line; do
      if echo "$line" | grep -Eq '^[[:space:]]*-[[:space:]]*name:[[:space:]]*'; then
        # Close previous group check
        if [[ "$in_group" == "true" && "$has_proxies" == "false" ]]; then
          issues+=("{\"rule\":\"PROXY_GROUP_EMPTY_PROXIES\",\"level\":\"error\",\"path\":\"proxy-groups[$group_name].proxies\",\"message\":\"proxy group '$group_name' has no proxies\",\"fixable\":false}")
        fi
        in_group=true
        group_name=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*name:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
        has_proxies=false
      elif echo "$line" | grep -Eq '^[[:space:]]*proxies:[[:space:]]*\[' && echo "$line" | grep -Eq '\[\s*\]'; then
        # proxies: [] on same line
        has_proxies=false
      elif echo "$line" | grep -Eq '^[[:space:]]*proxies:'; then
        has_proxies=true
      fi
    done < <(awk '/^[[:space:]]*proxy-groups:/{found=1; next} found && /^[^[:space:]]/{exit} found{print}' "$file")
    # Check last group
    if [[ "$in_group" == "true" && "$has_proxies" == "false" ]]; then
      issues+=("{\"rule\":\"PROXY_GROUP_EMPTY_PROXIES\",\"level\":\"error\",\"path\":\"proxy-groups[$group_name].proxies\",\"message\":\"proxy group '$group_name' has no proxies\",\"fixable\":false}")
    fi
  fi

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

  # R5: DNS_NAMESERVER_FORMAT
  if grep -Eq '^[[:space:]]+nameserver:' "$file"; then
    while IFS= read -r line; do
      ns=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*//')
      if [[ -n "$ns" ]] && ! echo "$ns" | grep -Eq '^(https?://|tls://|quic://|tcp://|udp://)'; then
        # Plain IP without protocol prefix
        if echo "$ns" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$|^\[?[0-9a-fA-F:]+\]?$'; then
          issues+=("{\"rule\":\"DNS_NAMESERVER_FORMAT\",\"level\":\"warn\",\"path\":\"dns.nameserver\",\"message\":\"plain IP without protocol: $ns (defaults to udp)\",\"fixable\":false,\"suggested\":\"udp://$ns\"}")
        fi
      fi
    done < <(awk '/^[[:space:]]*nameserver:/{found=1; next} found && /^[[:space:]]*-/{print; next} found && /^[[:space:]]*[^-[:space:]]/{found=0}' "$file")
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
