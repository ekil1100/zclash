#!/usr/bin/env bash
set -euo pipefail

# Compare declared compatibility rules vs implemented migrator rules.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPAT_DOC="$ROOT_DIR/docs/compat/mihomo-clash.md"
MIGRATOR_RUN="$ROOT_DIR/tools/config-migrator/run.sh"

if [[ ! -f "$COMPAT_DOC" || ! -f "$MIGRATOR_RUN" ]]; then
  echo "MIGRATOR_COMPAT_PARITY=FAIL"
  echo "MIGRATOR_COMPAT_PARITY_ERROR=missing_input_files"
  exit 1
fi

declared_rules=$( (grep -E '^- `[^`]+`$' "$COMPAT_DOC" || true) | sed -E 's/^- `([^`]+)`$/\1/' | sort -u )
implemented_rules=$( (grep -Eo 'PORT_TYPE_INT|LOG_LEVEL_ENUM' "$MIGRATOR_RUN" || true) | sort -u )

missing_in_impl=$(comm -23 <(printf '%s
' "$declared_rules") <(printf '%s
' "$implemented_rules") | sed '/^$/d')
undeclared_in_doc=$(comm -13 <(printf '%s
' "$declared_rules") <(printf '%s
' "$implemented_rules") | sed '/^$/d')

if [[ -n "$missing_in_impl" || -n "$undeclared_in_doc" ]]; then
  echo "MIGRATOR_COMPAT_PARITY=FAIL"
  echo "MIGRATOR_COMPAT_MISSING_IN_IMPL=$(echo "$missing_in_impl" | paste -sd, -)"
  echo "MIGRATOR_COMPAT_UNDECLARED_IN_DOC=$(echo "$undeclared_in_doc" | paste -sd, -)"
  exit 1
fi

echo "MIGRATOR_COMPAT_PARITY=PASS"
