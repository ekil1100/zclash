#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

case "$ACTION" in
  install)
    bash "$ROOT/oc-install.sh" "${@:2}"
    ;;
  verify)
    bash "$ROOT/oc-verify.sh" "${@:2}"
    ;;
  upgrade)
    bash "$ROOT/oc-upgrade.sh" "${@:2}"
    ;;
  *)
    echo "INSTALL_RESULT=FAIL"
    echo "INSTALL_ACTION=unknown"
    echo "INSTALL_REPORT="
    echo "INSTALL_FAILED_STEP=arg-parse"
    echo "INSTALL_NEXT_STEP=use: bash scripts/install/oc-run.sh <install|verify|upgrade>"
    echo "INSTALL_SUMMARY=unknown result=FAIL failed_step=arg-parse next_step=use: bash scripts/install/oc-run.sh <install|verify|upgrade>"
    exit 2
    ;;
esac
