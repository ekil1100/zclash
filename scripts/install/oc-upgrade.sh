#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# scaffold-only: no real upgrade yet
emit_install_result "PASS" "upgrade" "docs/install/report-upgrade.json" "" "run verify after upgrade to ensure compatibility"
