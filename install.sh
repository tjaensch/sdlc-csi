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
SCHEDULE_SET=false
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
      SCHEDULE_SET=true
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

VALID_RULESETS=()

if [[ -n "$RULESETS" ]]; then
  IFS=',' read -ra RULESET_ARRAY <<< "$RULESETS"
  for ruleset in "${RULESET_ARRAY[@]}"; do
    ruleset="$(echo "$ruleset" | xargs)"
    if [[ -f "$SCRIPT_DIR/rulesets/${ruleset}.md" ]]; then
      copy_file "$SCRIPT_DIR/rulesets/${ruleset}.md" "$RULESETS_DIR/${ruleset}.md"
      VALID_RULESETS+=("$ruleset")
    else
      echo "   ⚠ Ruleset '${ruleset}' not found in CSI distribution. Skipping."
    fi
  done
fi

# ── Helper: sync schedule in an existing .csi.yml when explicitly requested ─
sync_existing_schedule() {
  local config_path="$1"

  (
    local tmp_config
    tmp_config="$(mktemp "$(dirname "$config_path")/.csi-config-tmp.XXXXXX")"
    trap 'rm -f "$tmp_config"' EXIT

    if chmod --reference="$config_path" "$tmp_config" 2>/dev/null; then
      :
    else
      orig_mode="$(stat -f '%Lp' "$config_path" 2>/dev/null || true)"
      [[ -n "$orig_mode" ]] && chmod "$orig_mode" "$tmp_config"
    fi

    if ! awk -v schedule="$SCHEDULE" '
      BEGIN { updated = 0 }
      /^schedule:[[:space:]]*/ && updated == 0 {
        cr = (substr($0, length($0)) == "\r") ? "\r" : ""
        printf "schedule: \"%s\"%s\n", schedule, cr
        updated = 1
        next
      }
      { print }
      END { exit(updated ? 0 : 1) }
    ' "$config_path" > "$tmp_config"; then
      exit 1
    fi

    mv "$tmp_config" "$config_path"
  )
}

# ── Generate .csi.yml if missing ─────────────────────────────────────────
CSI_CONFIG="$REPO_PATH/.csi.yml"
if [[ -f "$CSI_CONFIG" ]]; then
  echo ""
  echo "📋 .csi.yml already exists — preserving your configuration."
  if [[ "$FORCE" == "true" && "$SCHEDULE_SET" == "true" ]]; then
    if sync_existing_schedule "$CSI_CONFIG"; then
      echo "   ✓ Updated schedule in: $CSI_CONFIG"
    else
      echo "   ⚠ Could not update schedule in: $CSI_CONFIG"
    fi
  fi
else
  echo ""
  echo "📋 Creating .csi.yml..."

  cp "$SCRIPT_DIR/examples/.csi.yml" "$CSI_CONFIG"

  python3 - "$CSI_CONFIG" "$SCHEDULE" "$BRANCH" "$BACKEND" "${VALID_RULESETS[@]}" <<'PY'
from pathlib import Path
import sys

config_path = Path(sys.argv[1])
schedule = sys.argv[2]
base_branch = sys.argv[3]
backend = sys.argv[4]
rulesets = sys.argv[5:]

lines = config_path.read_text(encoding="utf-8").splitlines()
output = []
i = 0

while i < len(lines):
    line = lines[i]

    if line.startswith("schedule:"):
        output.append(f'schedule: "{schedule}"')
    elif line.startswith("base_branch:"):
        output.append(f"base_branch: {base_branch}")
    elif line.startswith("backend:"):
        output.append(f"backend: {backend}")
    elif line.strip() == "tooling_currency: true" and backend == "openai":
        output.append("    tooling_currency: false")
    elif line.strip() == "dependency_health: true" and backend == "openai":
        output.append("    dependency_health: false")
    elif line.startswith("rulesets:"):
        if rulesets:
            output.append("rulesets:")
            output.extend(f"  - {ruleset}" for ruleset in rulesets)
            i += 1
            while i < len(lines) and (lines[i].startswith("  - ") or lines[i].startswith("  # - ")):
                i += 1
            continue
        output.append("rulesets: []")
    else:
        output.append(line)

    i += 1

config_path.write_text("\n".join(output) + "\n", encoding="utf-8")
PY

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
