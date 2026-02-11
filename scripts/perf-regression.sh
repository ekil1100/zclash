#!/usr/bin/env bash
set -euo pipefail

# Unified perf regression entrypoint
# Keep command stable for local/CI usage:
#   bash scripts/perf-regression.sh

usage() {
  cat <<'EOF'
Usage:
  bash scripts/perf-regression.sh [--help]

Description:
  Run placeholder perf regression baseline and print PASS/FAIL protocol.

Return codes:
  0  PASS (PERF_REGRESSION_RESULT=PASS)
  1  FAIL (PERF_REGRESSION_RESULT=FAIL)
  2  Invalid arguments
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "Invalid argument: $1" >&2
  usage >&2
  exit 2
fi

TARGET="$(cd "$(dirname "$0")" && pwd)/perf/run-baseline.sh"
if "$TARGET"; then
  # pass-through PASS semantics from baseline script
  exit 0
else
  echo "PERF_REGRESSION_RESULT=FAIL"
  exit 1
fi
