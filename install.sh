#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# install.sh — Install CSI (Continuous Self-Improvement) into a repository
#
# Run with --help for usage and options.
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Resolve script location ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────
REPO_PATH="."
RULESETS=""
BACKEND="copilot"
BRANCH="main"
SCHEDULE="0 10 * * 1"
FORCE=false

# ── Parse arguments ───────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-path)
      shift; REPO_PATH="${1:?--repo-path requires a path argument}"; shift ;;
    --rulesets)
      shift; RULESETS="${1:?--rulesets requires a comma-separated list}"; shift ;;
    --backend)
      shift; BACKEND="${1:?--backend requires 'copilot' or 'openai'}"; shift ;;
    --branch)
      shift; BRANCH="${1:?--branch requires a branch name}"; shift ;;
    --schedule)
      shift; SCHEDULE="${1:?--schedule requires a cron expression}"
      if [[ ! "$SCHEDULE" =~ ^[0-9\ \*,\-/]+$ ]]; then
        echo "Error: --schedule contains invalid characters. Only digits, spaces, *, comma, dash, and / are allowed." >&2
        exit 1
      fi
      # Require exactly 5 cron fields
      read -ra CRON_FIELDS <<< "$SCHEDULE"
      if [[ ${#CRON_FIELDS[@]} -ne 5 ]]; then
        echo "Error: --schedule must have exactly 5 cron fields (minute hour day month weekday). Got ${#CRON_FIELDS[@]}." >&2
        exit 1
      fi
      # Normalize whitespace (collapse multiple spaces, trim)
      SCHEDULE="${CRON_FIELDS[*]}"
      shift ;;
    --force)
      FORCE=true; shift ;;
    --help|-h)
      cat <<HELPEOF
Install CSI (Continuous Self-Improvement) into a repository.

Copies the CSI workflow, agent, and helper scripts into the target repo.
Creates a .csi.yml config file from a template if one doesn't already exist.

Usage:
  $(basename "$0") [OPTIONS]

Options:
  --repo-path <path>       Target repository root (default: current directory)
  --rulesets <list>         Comma-separated rulesets to enable (e.g., "python,javascript")
  --backend <name>         LLM backend: "copilot" or "openai" (default: copilot)
  --branch <name>          Base branch for PRs (default: main)
  --schedule <cron>        Cron schedule for automated scans (default: "0 10 * * 1")
  --force                  Overwrite existing CSI files (except .csi.yml)
  --help                   Show this help message
HELPEOF
      exit 0
      ;;
    *)
      echo "Error: Unknown argument '$1'. Use --help for usage." >&2
      exit 1
      ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────────
REPO_PATH="$(cd "$REPO_PATH" && pwd)"

if [[ ! -d "$REPO_PATH/.git" ]]; then
  echo "Error: '$REPO_PATH' is not a git repository." >&2
  exit 1
fi

if [[ "$BACKEND" != "copilot" && "$BACKEND" != "openai" ]]; then
  echo "Error: Backend must be 'copilot' or 'openai', got '$BACKEND'." >&2
  exit 1
fi

echo "🔧 Installing CSI into: $REPO_PATH"
echo "   Backend:  $BACKEND"
echo "   Branch:   $BRANCH"
echo "   Schedule: $SCHEDULE"
[[ -n "$RULESETS" ]] && echo "   Rulesets: $RULESETS"
if [[ "$BACKEND" == "openai" ]]; then
  echo ""
  echo "   ⚠ OpenAI backend: Tooling Currency and Dependency Health categories"
  echo "     are excluded (no internet access to verify external resources)."
fi

# ── Helper: copy file with optional force ─────────────────────────────────
copy_file() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  if [[ -f "$dst" && "$FORCE" != "true" ]]; then
    echo "   ⏭ Exists (skip): $dst"
    return 0
  fi

  # Skip if source and destination are the same file (self-install case)
  if [[ "$(realpath "$src" 2>/dev/null)" == "$(realpath "$dst" 2>/dev/null)" ]]; then
    echo "   ⏭ Same file (skip): $dst"
    return 0
  fi

  cp "$src" "$dst"
  echo "   ✓ Installed: $dst"
}

# ── Copy workflow ─────────────────────────────────────────────────────────
echo ""
echo "📦 Installing files..."

WORKFLOW_DST="$REPO_PATH/.github/workflows/csi-run.yml"
WORKFLOW_PREEXISTED=false
[[ -e "$WORKFLOW_DST" ]] && WORKFLOW_PREEXISTED=true

copy_file "$SCRIPT_DIR/.github/workflows/csi-run.yml" "$WORKFLOW_DST"

# Patch the schedule cron only when the workflow was actually installed/overwritten
WORKFLOW_SRC_REAL="$(realpath "$SCRIPT_DIR/.github/workflows/csi-run.yml" 2>/dev/null || true)"
WORKFLOW_DST_REAL="$(realpath "$WORKFLOW_DST" 2>/dev/null || true)"
if [[ ("$FORCE" == "true" || "$WORKFLOW_PREEXISTED" == "false") \
      && "$WORKFLOW_SRC_REAL" != "$WORKFLOW_DST_REAL" ]]; then
  (
    # Create temp file in same directory for atomic same-device rename
    tmp_workflow="$(mktemp "$(dirname "$WORKFLOW_DST")/.csi-tmp.XXXXXX")"
    trap 'rm -f "$tmp_workflow"' EXIT
    # Preserve original file permissions (portable: stat-based fallback for macOS)
    if chmod --reference="$WORKFLOW_DST" "$tmp_workflow" 2>/dev/null; then
      : # GNU chmod succeeded
    else
      # macOS/BSD fallback: copy permissions via stat
      orig_mode="$(stat -f '%Lp' "$WORKFLOW_DST" 2>/dev/null || true)"
      [[ -n "$orig_mode" ]] && chmod "$orig_mode" "$tmp_workflow"
    fi
    awk -v schedule="$SCHEDULE" '
      /^    - cron:/ {
        # Detect and preserve trailing CR (CRLF files)
        cr = (substr($0, length($0)) == "\r") ? "\r" : ""
        printf "    - cron: \047%s\047%s\n", schedule, cr
        next
      }
      { print }
    ' "$WORKFLOW_DST" > "$tmp_workflow"
    mv "$tmp_workflow" "$WORKFLOW_DST"
  )

  if ! grep -Fq "    - cron: '${SCHEDULE}'" "$WORKFLOW_DST"; then
    echo "Error: Failed to update workflow schedule to '${SCHEDULE}'." >&2
    exit 1
  fi
fi

copy_file "$SCRIPT_DIR/.github/agents/csi-maintainer.agent.md" "$REPO_PATH/.github/agents/csi-maintainer.agent.md"
copy_file "$SCRIPT_DIR/.github/scripts/install-copilot-cli.sh" "$REPO_PATH/.github/scripts/install-copilot-cli.sh"
copy_file "$SCRIPT_DIR/.github/scripts/sanitize-report.sh" "$REPO_PATH/.github/scripts/sanitize-report.sh"
copy_file "$SCRIPT_DIR/.github/scripts/openai-scan.py" "$REPO_PATH/.github/scripts/openai-scan.py"

# Make scripts executable
chmod +x "$REPO_PATH/.github/scripts/install-copilot-cli.sh"
chmod +x "$REPO_PATH/.github/scripts/sanitize-report.sh"

# ── Copy selected rulesets ────────────────────────────────────────────────
# Always copy generic ruleset
RULESETS_DIR="$REPO_PATH/.github/rulesets"
mkdir -p "$RULESETS_DIR"
copy_file "$SCRIPT_DIR/rulesets/generic.md" "$RULESETS_DIR/generic.md"

if [[ -n "$RULESETS" ]]; then
  IFS=',' read -ra RULESET_ARRAY <<< "$RULESETS"
  for ruleset in "${RULESET_ARRAY[@]}"; do
    ruleset="$(echo "$ruleset" | xargs)"
    if [[ -f "$SCRIPT_DIR/rulesets/${ruleset}.md" ]]; then
      copy_file "$SCRIPT_DIR/rulesets/${ruleset}.md" "$RULESETS_DIR/${ruleset}.md"
    else
      echo "   ⚠ Ruleset '${ruleset}' not found in CSI distribution. Skipping."
    fi
  done
fi

# ── Generate .csi.yml if missing ─────────────────────────────────────────
CSI_CONFIG="$REPO_PATH/.csi.yml"
if [[ -f "$CSI_CONFIG" ]]; then
  echo ""
  echo "📋 .csi.yml already exists — preserving your configuration."
else
  echo ""
  echo "📋 Creating .csi.yml..."

  # Build rulesets YAML list
  RULESETS_YAML="[]"
  TOOLING_CURRENCY_ENABLED="true"
  DEPENDENCY_HEALTH_ENABLED="true"

  if [[ "$BACKEND" == "openai" ]]; then
    TOOLING_CURRENCY_ENABLED="false"
    DEPENDENCY_HEALTH_ENABLED="false"
  fi

  if [[ -n "$RULESETS" ]]; then
    RULESETS_YAML=""
    IFS=',' read -ra RULESET_ARRAY <<< "$RULESETS"
    for ruleset in "${RULESET_ARRAY[@]}"; do
      ruleset="$(echo "$ruleset" | xargs)"
      RULESETS_YAML="${RULESETS_YAML}\n  - ${ruleset}"
    done
  fi

  cat > "$CSI_CONFIG" << CONFIG_EOF
# ─────────────────────────────────────────────────────────────────────────────
# .csi.yml — Continuous Self-Improvement configuration
# ─────────────────────────────────────────────────────────────────────────────
# Documentation: https://github.com/tjaensch/csi#configuration
# ─────────────────────────────────────────────────────────────────────────────
version: 1

schedule: "${SCHEDULE}"
base_branch: ${BRANCH}
stale_pr_days: 3

backend: ${BACKEND}
model: ""
timeout: 1800

scan:
  categories:
    dry_violations: true
    documentation_drift: true
    tooling_currency: ${TOOLING_CURRENCY_ENABLED}
    dead_code: true
    code_quality: true
    security_hygiene: true
    dependency_health: ${DEPENDENCY_HEALTH_ENABLED}
    config_consistency: true
  exclude_paths:
    - "vendor/**"
    - "node_modules/**"
    - "dist/**"
    - ".git/**"

rulesets: $(if [[ -n "$RULESETS" ]]; then echo ""; IFS=',' read -ra RA <<< "$RULESETS"; for r in "${RA[@]}"; do echo "  - $(echo "$r" | xargs)"; done; else echo "[]"; fi)

custom_rules: []
CONFIG_EOF

  echo "   ✓ Created: $CSI_CONFIG"
fi

# ── Post-install instructions ─────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ CSI installed successfully!"
echo ""
echo "Next steps:"
echo ""

if [[ "$BACKEND" == "copilot" ]]; then
  echo "  1. Add the COPILOT_TOKEN secret to your repository:"
  echo "     Settings → Secrets and variables → Actions → New repository secret"
  echo "     Name: COPILOT_TOKEN"
  echo "     Value: A GitHub PAT with Copilot access"
  echo ""
elif [[ "$BACKEND" == "openai" ]]; then
  echo "  1. Add the OPENAI_API_KEY secret to your repository:"
  echo "     Settings → Secrets and variables → Actions → New repository secret"
  echo "     Name: OPENAI_API_KEY"
  echo "     Value: Your OpenAI API key"
  echo "     ⚠ Note: OpenAI backend is scan-only (no auto-fix). Use Copilot for full functionality."
  echo ""
fi

echo "  2. Review and customize .csi.yml to match your project."
echo ""
echo "  3. Trigger your first scan:"
echo "     gh workflow run csi-run.yml -f dry_run=true"
echo ""
echo "  4. Commit the installed files:"
echo "     git add .csi.yml .github/workflows/csi-run.yml .github/agents/ .github/scripts/ .github/rulesets/"
echo "     git commit -m 'chore: install CSI automated maintenance'"
echo "     git push"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
