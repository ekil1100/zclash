#!/usr/bin/env bash
set -euo pipefail

# Compatibility entrypoint for P4-1.E
# Keep command stable for local/CI usage:
#   bash scripts/perf-regression.sh

exec "$(cd "$(dirname "$0")" && pwd)/perf/run-baseline.sh" "$@"
