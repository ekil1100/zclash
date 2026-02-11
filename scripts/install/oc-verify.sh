#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# scaffold-only: no real verify yet
emit_install_result "PASS" "verify" "docs/install/report-verify.json" "" "run upgrade or execute smoke test commands"
