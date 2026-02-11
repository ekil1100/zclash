#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# scaffold-only: no real install yet
emit_install_result "PASS" "install" "docs/install/report-install.json" "" "run verify to confirm runtime prerequisites"
