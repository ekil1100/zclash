#!/usr/bin/env bash
set -euo pipefail

# Minimal regression for install/verify/upgrade success + failure samples.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT_DIR/scripts/install/oc-run.sh"
TMP_DIR="/tmp/zclash-install-regression"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

ok() {
  local out="$1"
  grep -q 'INSTALL_RESULT=PASS' "$out"
  grep -q 'INSTALL_ACTION=' "$out"
  grep -q 'INSTALL_REPORT=' "$out"
  grep -q 'INSTALL_NEXT_STEP=' "$out"
}

fail_case() {
  local out="$1"
  grep -q 'INSTALL_RESULT=FAIL' "$out"
  grep -q 'INSTALL_FAILED_STEP=' "$out"
  grep -q 'INSTALL_NEXT_STEP=' "$out"
}

# success: install -> verify -> upgrade
bash "$RUNNER" install --target-dir "$TMP_DIR" > "$TMP_DIR/install.pass.out"
ok "$TMP_DIR/install.pass.out"

bash "$RUNNER" verify --target-dir "$TMP_DIR" > "$TMP_DIR/verify.pass.out"
ok "$TMP_DIR/verify.pass.out"

bash "$RUNNER" upgrade --target-dir "$TMP_DIR" --version v0.2.0 > "$TMP_DIR/upgrade.pass.out"
ok "$TMP_DIR/upgrade.pass.out"

# failure sample 1: verify before install
rm -rf "$TMP_DIR/empty"
mkdir -p "$TMP_DIR/empty"
if bash "$RUNNER" verify --target-dir "$TMP_DIR/empty" > "$TMP_DIR/verify.fail.out" 2>&1; then
  echo "INSTALL_FLOW_REGRESSION=FAIL"
  echo "INSTALL_FLOW_REGRESSION_REASON=verify_before_install_should_fail"
  exit 1
fi
fail_case "$TMP_DIR/verify.fail.out"

# failure sample 2: upgrade without version
if bash "$RUNNER" upgrade --target-dir "$TMP_DIR" > "$TMP_DIR/upgrade.fail.out" 2>&1; then
  echo "INSTALL_FLOW_REGRESSION=FAIL"
  echo "INSTALL_FLOW_REGRESSION_REASON=upgrade_without_version_should_fail"
  exit 1
fi
fail_case "$TMP_DIR/upgrade.fail.out"

echo "INSTALL_FLOW_REGRESSION=PASS"
echo "INSTALL_FLOW_REGRESSION_REPORT=$TMP_DIR"
