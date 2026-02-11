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

# P5-1B scaffold only: emit contract-shaped placeholder output
if [[ "$MODE" == "lint" ]]; then
  echo '{"ok":true,"mode":"lint","issues":[{"rule":"PORT_TYPE_INT","level":"warn","path":"mixed-port","message":"string numeric can be autofixed to int","fixable":true},{"rule":"LOG_LEVEL_ENUM","level":"error","path":"log-level","message":"value out of enum","fixable":false}],"fixed":0,"hint":"run autofix for fixable issues"}'
  exit 0
fi

# autofix placeholder
cp "$INPUT" "${OUT:-$INPUT.bak}"
echo '{"ok":true,"mode":"autofix","issues":[],"fixed":1,"hint":"placeholder autofix wrote backup/output"}'
