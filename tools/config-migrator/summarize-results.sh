#!/usr/bin/env bash
set -euo pipefail

# Aggregate migrator sample verification results to a unified archive-compatible summary.
# Offline reproducible command:
#   bash tools/config-migrator/summarize-results.sh

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/tools/config-migrator/reports"
INPUT="$REPORT_DIR/samples-report.json"
OUTPUT="$REPORT_DIR/samples-summary.json"

if [[ ! -f "$INPUT" ]]; then
  echo "MIGRATOR_SUMMARY_RESULT=FAIL"
  echo "MIGRATOR_SUMMARY_ERROR=input report missing: $INPUT"
  exit 1
fi

node - <<'NODE' "$INPUT" "$OUTPUT"
const fs = require('fs');
const input = process.argv[2];
const output = process.argv[3];
const src = JSON.parse(fs.readFileSync(input, 'utf8'));

const results = (src.results || []).map(r => ({
  sample_id: r.sample || r.sample_id || 'unknown',
  input: r.input || '',
  result: (r.status || r.result || 'FAIL').toUpperCase(),
  diff: r.diff || '',
  hint: r.hint || r.reason || ''
}));

const passCount = results.filter(r => r.result === 'PASS').length;
const failItems = results.filter(r => r.result !== 'PASS').map(r => ({
  sample_id: r.sample_id,
  hint: r.hint
}));

const out = {
  run_id: src.run_id || `migrator-summary-${Date.now()}`,
  status: failItems.length ? 'FAIL' : 'PASS',
  pass_count: passCount,
  fail_count: failItems.length,
  failed_items: failItems,
  results
};

fs.writeFileSync(output, JSON.stringify(out, null, 2) + '\n');
NODE

echo "MIGRATOR_SUMMARY_RESULT=PASS"
echo "MIGRATOR_SUMMARY_REPORT=tools/config-migrator/reports/samples-summary.json"
