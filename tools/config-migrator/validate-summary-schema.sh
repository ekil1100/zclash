#!/usr/bin/env bash
set -euo pipefail

# Validate schema for tools/config-migrator/reports/samples-summary.json

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FILE="$ROOT_DIR/tools/config-migrator/reports/samples-summary.json"

if [[ ! -f "$FILE" ]]; then
  echo "MIGRATOR_SCHEMA_VALIDATE=FAIL"
  echo "MIGRATOR_SCHEMA_MISSING_FIELDS=file_not_found"
  exit 1
fi

node - <<'NODE' "$FILE"
const fs = require('fs');
const file = process.argv[2];
const obj = JSON.parse(fs.readFileSync(file, 'utf8'));

const missing = [];
const requiredTop = ['run_id', 'status', 'pass_count', 'fail_count', 'failed_items', 'results'];
for (const k of requiredTop) {
  if (!(k in obj)) missing.push(k);
}

if (!Array.isArray(obj.results)) {
  missing.push('results(array)');
} else {
  obj.results.forEach((r, i) => {
    ['sample_id', 'input', 'result', 'diff', 'hint'].forEach((k) => {
      if (!(k in r)) missing.push(`results[${i}].${k}`);
    });
  });
}

if (missing.length > 0) {
  console.log('MIGRATOR_SCHEMA_VALIDATE=FAIL');
  console.log('MIGRATOR_SCHEMA_MISSING_FIELDS=' + missing.join(','));
  process.exit(1);
}

console.log('MIGRATOR_SCHEMA_VALIDATE=PASS');
NODE
