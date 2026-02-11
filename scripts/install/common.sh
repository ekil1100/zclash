#!/usr/bin/env bash
set -euo pipefail

emit_install_result() {
  local result="$1"   # PASS|FAIL
  local action="$2"   # install|verify|upgrade
  local report="$3"
  local failed_step="${4:-}"
  local next_step="${5:-}"

  echo "INSTALL_RESULT=$result"
  echo "INSTALL_ACTION=$action"
  echo "INSTALL_REPORT=$report"
  echo "INSTALL_FAILED_STEP=$failed_step"
  echo "INSTALL_NEXT_STEP=$next_step"
  echo "INSTALL_SUMMARY=$action result=$result failed_step=${failed_step:-none} next_step=${next_step:-none}"
}
