#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# test-install.sh — Validate the CSI installer and uninstaller
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

assert_file_exists() {
  if [[ -f "$1" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: Expected file to exist: $1"
  fi
}

assert_file_not_exists() {
  if [[ ! -f "$1" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: Expected file to NOT exist: $1"
  fi
}

assert_file_contains() {
  if grep -q "$2" "$1" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: Expected '$1' to contain '$2'"
  fi
}

assert_output_contains() {
  local output="$1"
  local expected="$2"

  if grep -Fq -- "$expected" <<< "$output"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: Expected output to contain '$expected'"
  fi
}

assert_output_not_contains() {
  local output="$1"
  local unexpected="$2"

  local rc=0
  grep -Fq -- "$unexpected" <<< "$output" || rc=$?
  if [[ $rc -eq 1 ]]; then
    # exit 1 = not found — pass
    PASS=$((PASS + 1))
  elif [[ $rc -eq 0 ]]; then
    # exit 0 = found — fail
    FAIL=$((FAIL + 1))
    echo "  FAIL: Expected output to NOT contain '$unexpected'"
  else
    # exit 2+ = grep error — fail with diagnostic
    FAIL=$((FAIL + 1))
    echo "  FAIL: grep error (exit $rc) while checking for '$unexpected'"
  fi
}

# ── Test 1: Fresh install ─────────────────────────────────────────────────
echo "Test 1: Fresh install with defaults"
REPO1="$TEST_DIR/repo1"
mkdir -p "$REPO1" && cd "$REPO1" && git init -q

bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO1"

assert_file_exists "$REPO1/.csi.yml"
assert_file_exists "$REPO1/.github/workflows/csi-run.yml"
assert_file_exists "$REPO1/.github/agents/csi-maintainer.agent.md"
assert_file_exists "$REPO1/.github/scripts/install-copilot-cli.sh"
assert_file_exists "$REPO1/.github/scripts/sanitize-report.sh"
assert_file_exists "$REPO1/.github/scripts/openai-scan.py"
assert_file_exists "$REPO1/.github/rulesets/generic.md"
assert_file_contains "$REPO1/.csi.yml" "backend: copilot"
assert_file_contains "$REPO1/.csi.yml" "base_branch: main"
echo ""

# ── Test 2: Idempotency — .csi.yml preserved ─────────────────────────────
echo "Test 2: Re-install preserves .csi.yml"
echo "# custom comment" >> "$REPO1/.csi.yml"

bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO1"

assert_file_contains "$REPO1/.csi.yml" "# custom comment"
echo ""

# ── Test 3: Install with rulesets and options ─────────────────────────────
echo "Test 3: Install with rulesets and custom options"
REPO2="$TEST_DIR/repo2"
mkdir -p "$REPO2" && cd "$REPO2" && git init -q

bash "$SCRIPT_DIR/install.sh" \
  --repo-path "$REPO2" \
  --rulesets "python,javascript" \
  --backend "openai" \
  --branch "develop" \
  --schedule "0 8 * * *"

assert_file_exists "$REPO2/.github/rulesets/python.md"
assert_file_exists "$REPO2/.github/rulesets/javascript.md"
assert_file_contains "$REPO2/.csi.yml" "backend: openai"
assert_file_contains "$REPO2/.csi.yml" "base_branch: develop"
echo ""

# ── Test 4: Uninstall preserves config ────────────────────────────────────
echo "Test 4: Uninstall preserves .csi.yml"

bash "$SCRIPT_DIR/uninstall.sh" --repo-path "$REPO1"

assert_file_exists "$REPO1/.csi.yml"
assert_file_not_exists "$REPO1/.github/workflows/csi-run.yml"
assert_file_not_exists "$REPO1/.github/agents/csi-maintainer.agent.md"
assert_file_not_exists "$REPO1/.github/scripts/install-copilot-cli.sh"
echo ""

# ── Test 5: Uninstall with --remove-config ────────────────────────────────
echo "Test 5: Uninstall with --remove-config"

mkdir -p "$REPO2/.github/rulesets"
echo "# custom ruleset" > "$REPO2/.github/rulesets/my-custom-rules.md"

bash "$SCRIPT_DIR/uninstall.sh" --repo-path "$REPO2" --remove-config

assert_file_exists "$REPO2/.github/rulesets/my-custom-rules.md"
assert_file_not_exists "$REPO2/.github/rulesets/generic.md"
assert_file_not_exists "$REPO2/.github/rulesets/python.md"
assert_file_not_exists "$REPO2/.github/rulesets/javascript.md"
assert_file_not_exists "$REPO2/.csi.yml"
echo ""

# ── Test 6: Help output should stay user-facing ───────────────────────────
echo "Test 6: Install help output"
INSTALL_HELP_OUTPUT="$(bash "$SCRIPT_DIR/install.sh" --help)"

assert_output_contains "$INSTALL_HELP_OUTPUT" "Usage:"
assert_output_contains "$INSTALL_HELP_OUTPUT" "--schedule <cron>"
assert_output_not_contains "$INSTALL_HELP_OUTPUT" "set -euo pipefail"
echo ""

# ── Test 7: Non-git directory should fail ─────────────────────────────────
echo "Test 7: Reject non-git directory"
NON_GIT="$TEST_DIR/not-a-repo"
mkdir -p "$NON_GIT"
if bash "$SCRIPT_DIR/install.sh" --repo-path "$NON_GIT" 2>/dev/null; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: Should have rejected non-git directory"
else
  PASS=$((PASS + 1))
fi
echo ""

# ── Test 8: Uninstall help output should stay user-facing ─────────────────
echo "Test 8: Uninstall help output"
UNINSTALL_HELP_OUTPUT="$(bash "$SCRIPT_DIR/uninstall.sh" --help)"

assert_output_contains "$UNINSTALL_HELP_OUTPUT" "Usage:"
assert_output_contains "$UNINSTALL_HELP_OUTPUT" "--remove-config"
assert_output_not_contains "$UNINSTALL_HELP_OUTPUT" "# ─"
assert_output_not_contains "$UNINSTALL_HELP_OUTPUT" "# Usage:"
assert_output_not_contains "$UNINSTALL_HELP_OUTPUT" "set -euo pipefail"
echo ""

# ── Results ───────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
