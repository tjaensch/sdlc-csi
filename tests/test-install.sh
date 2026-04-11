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
  if grep -q -- "$2" "$1" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: Expected '$1' to contain '$2'"
  fi
}

assert_file_matches() {
  # Regex assertion that tolerates optional \r (CRLF endings)
  if sed 's/\r$//' "$1" | grep -qE -- "$2" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: Expected '$1' to match regex '$2'"
  fi
}

assert_file_not_contains() {
  local rc=0
  grep -q -- "$2" "$1" 2>/dev/null || rc=$?
  if [[ $rc -eq 1 ]]; then
    PASS=$((PASS + 1))
  elif [[ $rc -eq 0 ]]; then
    FAIL=$((FAIL + 1))
    echo "  FAIL: Expected '$1' to NOT contain '$2'"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: grep error (exit $rc) while checking '$1' for '$2'"
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
assert_file_exists "$REPO1/.github/rulesets/generic.md"
assert_file_contains "$REPO1/.csi.yml" "Place this file in the root of your repository"
assert_file_contains "$REPO1/.csi.yml" "base_branch: main"
assert_file_contains "$REPO1/.csi.yml" "timeout: 1800"
assert_file_contains "$REPO1/.github/workflows/csi-run.yml" "cron: '0 10 \* \* 1'"
assert_file_contains "$REPO1/.github/workflows/csi-run.yml" 'ALL_RULESETS=("generic")'
echo ""

# ── Test 1b: Existing .csi.yml schedule is respected on install ───────────
echo "Test 1b: Existing .csi.yml schedule is respected on install"
REPO1B="$TEST_DIR/repo1b"
mkdir -p "$REPO1B" && cd "$REPO1B" && git init -q
cat > "$REPO1B/.csi.yml" <<'EOF'
version: 1
schedule: "15 7 * * 2"
base_branch: main
stale_pr_days: 3
timeout: 1800
scan:
  categories:
    dry_violations: true
    documentation_drift: true
    tooling_currency: true
    dead_code: true
    code_quality: true
    security_hygiene: true
    dependency_health: true
    config_consistency: true
  exclude_paths:
    - "vendor/**"
    - "node_modules/**"
    - "dist/**"
    - ".git/**"
rulesets: []
custom_rules: []
EOF

INSTALL_OUTPUT_REPO1B="$(bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO1B")"
assert_output_contains "$INSTALL_OUTPUT_REPO1B" "Schedule: 15 7 * * 2"

assert_file_contains "$REPO1B/.github/workflows/csi-run.yml" "cron: '15 7 \* \* 2'"
assert_file_contains "$REPO1B/.csi.yml" 'schedule: "15 7 \* \* 2"'
echo ""

# ── Test 2: Idempotency — .csi.yml preserved ─────────────────────────────
echo "Test 2: Re-install preserves .csi.yml"
echo "# custom comment" >> "$REPO1/.csi.yml"

bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO1"

assert_file_contains "$REPO1/.csi.yml" "# custom comment"
echo ""

# ── Test 2b: Force re-install syncs explicit schedule changes ─────────────
echo "Test 2b: Re-install with --force syncs schedule into .csi.yml"

bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO1" --schedule "15 7 * * 2" --force

assert_file_contains "$REPO1/.csi.yml" 'schedule: "15 7 \* \* 2"'
assert_file_contains "$REPO1/.github/workflows/csi-run.yml" "cron: '15 7 \* \* 2'"
assert_file_contains "$REPO1/.csi.yml" "# custom comment"
echo ""

# ── Test 2c: Force re-install syncs explicit base branch changes ──────────
echo "Test 2c: Re-install with --force syncs base branch into .csi.yml"

bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO1" --branch "develop" --force

assert_file_contains "$REPO1/.csi.yml" 'base_branch: develop'
assert_file_contains "$REPO1/.csi.yml" "# custom comment"
assert_file_contains "$REPO1/.github/workflows/csi-run.yml" "cron: '15 7 \* \* 2'"
echo ""

# ── Test 2d: Force re-install syncs explicit ruleset changes ──────────────
echo "Test 2d: Re-install with --force syncs rulesets into .csi.yml"

# First install with a single ruleset so the config has an active entry
bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO1" --rulesets "python" --force
assert_file_matches "$REPO1/.csi.yml" '^  - python$'

# Now force-reinstall with a different set — old entry should be replaced
bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO1" --rulesets "bash,python" --force

assert_file_matches "$REPO1/.csi.yml" '^  - bash$'
assert_file_matches "$REPO1/.csi.yml" '^  - python$'
RULESET_COUNT="$(sed 's/\r$//' "$REPO1/.csi.yml" | grep -c '^  - ')"
if [[ "$RULESET_COUNT" -eq 2 ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: Expected exactly 2 active rulesets after sync, found $RULESET_COUNT"
fi
assert_file_contains "$REPO1/.csi.yml" "# custom comment"
echo ""

echo "Test 2e: Re-install with only invalid rulesets clears previous rulesets"
bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO1" --rulesets "not-a-real-ruleset" --force
assert_file_contains "$REPO1/.csi.yml" "rulesets:"
assert_file_not_contains "$REPO1/.csi.yml" "  - bash"
assert_file_not_contains "$REPO1/.csi.yml" "  - python"
assert_file_contains "$REPO1/.csi.yml" "# custom comment"
echo ""

# ── Test 3: Install with rulesets and options ─────────────────────────────
echo "Test 3: Install with rulesets and custom options"
REPO2="$TEST_DIR/repo2"
mkdir -p "$REPO2" && cd "$REPO2" && git init -q

bash "$SCRIPT_DIR/install.sh" \
  --repo-path "$REPO2" \
  --rulesets "python,javascript" \
  --branch "develop" \
  --schedule "0 8 * * *"

assert_file_exists "$REPO2/.github/rulesets/python.md"
assert_file_exists "$REPO2/.github/rulesets/javascript.md"
assert_file_matches "$REPO2/.csi.yml" 'base_branch: develop'
assert_file_matches "$REPO2/.csi.yml" '^  - python$'
assert_file_matches "$REPO2/.csi.yml" '^  - javascript$'
assert_file_contains "$REPO2/.github/workflows/csi-run.yml" "cron: '0 8 \* \* \*'"
echo ""

# ── Test 4: Unknown rulesets are omitted from config ─────────────────────
echo "Test 4: Unknown rulesets are omitted from config"
REPO3="$TEST_DIR/repo3"
mkdir -p "$REPO3" && cd "$REPO3" && git init -q

bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO3" --rulesets "python,not-a-real-ruleset"

assert_file_exists "$REPO3/.github/rulesets/python.md"
assert_file_contains "$REPO3/.csi.yml" "rulesets:"
assert_file_matches "$REPO3/.csi.yml" '^  - python$'
assert_file_not_contains "$REPO3/.csi.yml" "not-a-real-ruleset"
echo ""

# ── Test 5: Uninstall preserves config ────────────────────────────────────
echo "Test 5: Uninstall preserves .csi.yml"

bash "$SCRIPT_DIR/uninstall.sh" --repo-path "$REPO1"

assert_file_exists "$REPO1/.csi.yml"
assert_file_not_exists "$REPO1/.github/workflows/csi-run.yml"
assert_file_not_exists "$REPO1/.github/agents/csi-maintainer.agent.md"
assert_file_not_exists "$REPO1/.github/scripts/install-copilot-cli.sh"
echo ""

# ── Test 6: Uninstall with --remove-config ────────────────────────────────
echo "Test 6: Uninstall with --remove-config"

mkdir -p "$REPO2/.github/rulesets"
echo "# custom ruleset" > "$REPO2/.github/rulesets/my-custom-rules.md"

bash "$SCRIPT_DIR/uninstall.sh" --repo-path "$REPO2" --remove-config

assert_file_exists "$REPO2/.github/rulesets/my-custom-rules.md"
assert_file_not_exists "$REPO2/.github/rulesets/generic.md"
assert_file_not_exists "$REPO2/.github/rulesets/python.md"
assert_file_not_exists "$REPO2/.github/rulesets/javascript.md"
assert_file_not_exists "$REPO2/.csi.yml"
echo ""

# ── Test 7: Help output should stay user-facing ───────────────────────────
echo "Test 7: Install help output"
INSTALL_HELP_OUTPUT="$(bash "$SCRIPT_DIR/install.sh" --help)"

assert_output_contains "$INSTALL_HELP_OUTPUT" "Usage:"
assert_output_contains "$INSTALL_HELP_OUTPUT" "--schedule <cron>"
assert_output_not_contains "$INSTALL_HELP_OUTPUT" "set -euo pipefail"
echo ""

# ── Test 8: Non-git directory should fail ─────────────────────────────────
echo "Test 8: Reject non-git directory"
NON_GIT="$TEST_DIR/not-a-repo"
mkdir -p "$NON_GIT"
if bash "$SCRIPT_DIR/install.sh" --repo-path "$NON_GIT" 2>/dev/null; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: Should have rejected non-git directory"
else
  PASS=$((PASS + 1))
fi
echo ""

# ── Test 9: Uninstall help output should stay user-facing ─────────────────
echo "Test 9: Uninstall help output"
UNINSTALL_HELP_OUTPUT="$(bash "$SCRIPT_DIR/uninstall.sh" --help)"

assert_output_contains "$UNINSTALL_HELP_OUTPUT" "Usage:"
assert_output_contains "$UNINSTALL_HELP_OUTPUT" "--remove-config"
assert_output_not_contains "$UNINSTALL_HELP_OUTPUT" "# ─"
assert_output_not_contains "$UNINSTALL_HELP_OUTPUT" "# Usage:"
assert_output_not_contains "$UNINSTALL_HELP_OUTPUT" "set -euo pipefail"
echo ""

# ── Test 10: Sanitize modern API keys and workflow PATs ───────────────────
echo "Test 10: Sanitize modern API keys and workflow PATs"
SANITIZE_INPUT="$TEST_DIR/sanitize-input.txt"
SANITIZE_OUTPUT="$TEST_DIR/sanitize-output.txt"
cat > "$SANITIZE_INPUT" <<'EOF'
Token seen: sk-proj-abcdefghijklmnopqrstuvwxyz1234567890
CSI_PAT=github_pat_abcdefghijklmnopqrstuvwxyz1234567890
EOF
bash "$SCRIPT_DIR/.github/scripts/sanitize-report.sh" "$SANITIZE_INPUT" "$SANITIZE_OUTPUT"
SANITIZED_CONTENT="$(cat "$SANITIZE_OUTPUT")"
assert_output_contains "$SANITIZED_CONTENT" "[REDACTED_TOKEN]"
assert_output_contains "$SANITIZED_CONTENT" "CSI_PAT=[REDACTED]"
assert_output_not_contains "$SANITIZED_CONTENT" "sk-proj-abcdefghijklmnopqrstuvwxyz1234567890"
assert_output_not_contains "$SANITIZED_CONTENT" "CSI_PAT=github_pat_abcdefghijklmnopqrstuvwxyz1234567890"
echo ""

# ── Test 11: Invalid schedule characters rejected ─────────────────────────
echo "Test 11: Reject invalid --schedule characters"
REPO_SCHED="$TEST_DIR/repo_sched"
mkdir -p "$REPO_SCHED" && cd "$REPO_SCHED" && git init -q
if bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO_SCHED" --schedule "'; echo pwned'" 2>/dev/null; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: Should have rejected schedule with quotes"
else
  PASS=$((PASS + 1))
fi
echo ""

# ── Test 12: Reject schedule with wrong number of fields ──────────────────
echo "Test 12: Reject --schedule with wrong field count"
if bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO_SCHED" --schedule "0 8 *" 2>/dev/null; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: Should have rejected schedule with 3 fields"
else
  PASS=$((PASS + 1))
fi
if bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO_SCHED" --schedule "1" 2>/dev/null; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: Should have rejected schedule with 1 field"
else
  PASS=$((PASS + 1))
fi
echo ""

# ── Test 13: Reject schedule fields outside supported cron ranges ─────────
echo "Test 13: Reject out-of-range cron fields"
if bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO_SCHED" --schedule "60 24 32 13 8" 2>/dev/null; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: Should have rejected schedule with out-of-range values"
else
  PASS=$((PASS + 1))
fi
echo ""

# ── Test 14: Reject invalid cron step values ──────────────────────────────
echo "Test 14: Reject invalid cron step values"
if bash "$SCRIPT_DIR/install.sh" --repo-path "$REPO_SCHED" --schedule "*/0 * * * *" 2>/dev/null; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: Should have rejected schedule with zero step"
else
  PASS=$((PASS + 1))
fi
echo ""

# ── Results ───────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
