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
RULESETS_SET=false
BRANCH="main"
BRANCH_SET=false
SCHEDULE="0 10 * * 1"
SCHEDULE_SET=false
FORCE=false

validate_cron_numeric() {
  local value="$1"
  local min="$2"
  local max="$3"

  [[ "$value" =~ ^[0-9]+$ ]] || return 1
  (( 10#$value >= min && 10#$value <= max ))
}

validate_cron_segment() {
  local segment="$1"
  local min="$2"
  local max="$3"

  if [[ "$segment" == "*" ]]; then
    return 0
  fi

  if [[ "$segment" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    local range_start="${BASH_REMATCH[1]}"
    local range_end="${BASH_REMATCH[2]}"
    validate_cron_numeric "$range_start" "$min" "$max" || return 1
    validate_cron_numeric "$range_end" "$min" "$max" || return 1
    (( 10#$range_start <= 10#$range_end ))
    return $?
  fi

  validate_cron_numeric "$segment" "$min" "$max"
}

validate_cron_field() {
  local field="$1"
  local min="$2"
  local max="$3"
  local item base step extra
  local -a items

  [[ -n "$field" ]] || return 1
  [[ "$field" != ,* && "$field" != *, && "$field" != *,,* ]] || return 1
  IFS=',' read -ra items <<< "$field"
  for item in "${items[@]}"; do
    [[ -n "$item" ]] || return 1

    base="$item"
    step=""
    extra=""
    if [[ "$item" == */* ]]; then
      [[ "$item" != */ ]] || return 1
      IFS='/' read -r base step extra <<< "$item"
      [[ -n "$base" && -n "$step" && -z "$extra" ]] || return 1
      [[ "$step" =~ ^[0-9]+$ ]] || return 1
      (( 10#$step > 0 )) || return 1
    fi

    validate_cron_segment "$base" "$min" "$max" || return 1
  done
}

validate_cron_expression() {
  local minute="$1"
  local hour="$2"
  local day="$3"
  local month="$4"
  local weekday="$5"

  validate_cron_field "$minute" 0 59 &&
    validate_cron_field "$hour" 0 23 &&
    validate_cron_field "$day" 1 31 &&
    validate_cron_field "$month" 1 12 &&
    validate_cron_field "$weekday" 0 7
}

read_config_schedule() {
  local config_path="$1"
  local config_schedule
  local -a config_fields

  config_schedule="$(sed -nE 's/^schedule:[[:space:]]*["\x27]?([^"\x27]+)["\x27]?[[:space:]]*$/\1/p' "$config_path" | head -n 1)"
  [[ -n "$config_schedule" ]] || return 1

  read -ra config_fields <<< "$config_schedule"
  [[ ${#config_fields[@]} -eq 5 ]] || return 1
  validate_cron_expression "${config_fields[0]}" "${config_fields[1]}" "${config_fields[2]}" "${config_fields[3]}" "${config_fields[4]}" || return 1

  printf '%s\n' "$config_schedule"
}

# ── Parse arguments ───────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-path)
      shift; REPO_PATH="${1:?--repo-path requires a path argument}"; shift ;;
    --rulesets)
      shift; RULESETS="${1:?--rulesets requires a comma-separated list}"; RULESETS_SET=true; shift ;;
    --branch)
      shift; BRANCH="${1:?--branch requires a branch name}"; BRANCH_SET=true; shift ;;
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
      if ! validate_cron_expression "${CRON_FIELDS[0]}" "${CRON_FIELDS[1]}" "${CRON_FIELDS[2]}" "${CRON_FIELDS[3]}" "${CRON_FIELDS[4]}"; then
        echo "Error: --schedule must use valid cron values within GitHub Actions ranges." >&2
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

# When installing into a repo that already has .csi.yml, keep its schedule in sync.
if [[ "$SCHEDULE_SET" == "false" && "$WORKFLOW_PREEXISTED" == "false" && -f "$REPO_PATH/.csi.yml" ]]; then
  existing_config_schedule="$(read_config_schedule "$REPO_PATH/.csi.yml" || true)"
  if [[ -n "$existing_config_schedule" ]]; then
    SCHEDULE="$existing_config_schedule"
  else
    echo "   ⚠ Existing .csi.yml schedule is invalid; using default schedule '${SCHEDULE}'."
  fi
fi

# When forcing without an explicit --schedule, preserve the existing workflow cron
if [[ "$FORCE" == "true" && "$SCHEDULE_SET" == "false" && "$WORKFLOW_PREEXISTED" == "true" ]]; then
  existing_cron="$(grep -m1 "[[:space:]]*-[[:space:]]*cron:" "$WORKFLOW_DST" | sed "s/.*cron:[[:space:]]*['\"]\\{0,1\\}//; s/['\"]\\{0,1\\}[[:space:]]*$//" || true)"
  if [[ -n "$existing_cron" ]]; then
    read -ra EC_FIELDS <<< "$existing_cron"
    if [[ ${#EC_FIELDS[@]} -eq 5 ]] \
       && validate_cron_expression "${EC_FIELDS[0]}" "${EC_FIELDS[1]}" "${EC_FIELDS[2]}" "${EC_FIELDS[3]}" "${EC_FIELDS[4]}"; then
      SCHEDULE="$existing_cron"
    else
      echo "   ⚠ Existing workflow cron '${existing_cron}' is invalid; using default schedule '${SCHEDULE}'."
    fi
  fi
fi

echo "🔧 Installing CSI into: $REPO_PATH"
echo "   Branch:   $BRANCH"
echo "   Schedule: $SCHEDULE"
[[ -n "$RULESETS" ]] && echo "   Rulesets: $RULESETS"

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

# ── Helpers: sync schedule/base_branch/rulesets in .csi.yml ─────────────────
# Helper: create a temp file preserving permissions of the original
make_config_tmp() {
  local config_path="$1"
  local tmp_config
  tmp_config="$(mktemp "$(dirname "$config_path")/.csi-config-tmp.XXXXXX")"
  if chmod --reference="$config_path" "$tmp_config" 2>/dev/null; then
    :
  else
    local orig_mode
    orig_mode="$(stat -f '%Lp' "$config_path" 2>/dev/null || true)"
    [[ -n "$orig_mode" ]] && chmod "$orig_mode" "$tmp_config"
  fi
  echo "$tmp_config"
}

sync_existing_schedule() {
  local config_path="$1"

  (
    local tmp_config
    tmp_config="$(make_config_tmp "$config_path")"
    trap 'rm -f "$tmp_config"' EXIT

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


sync_existing_base_branch() {
  local config_path="$1"

  (
    local tmp_config
    tmp_config="$(make_config_tmp "$config_path")"
    trap 'rm -f "$tmp_config"' EXIT

    if ! awk -v branch="$BRANCH" '
      BEGIN { updated = 0 }
      /^base_branch:[[:space:]]*/ && updated == 0 {
        cr = (substr($0, length($0)) == "\r") ? "\r" : ""
        printf "base_branch: %s%s\n", branch, cr
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

sync_existing_rulesets() {
  local config_path="$1"
  local rulesets_yaml="$2"

  (
    local tmp_config
    tmp_config="$(make_config_tmp "$config_path")"
    trap 'rm -f "$tmp_config"' EXIT

    if ! RULESETS_YAML_ENV="$rulesets_yaml" awk '
      BEGIN {
        updated = 0
        count = split(ENVIRON["RULESETS_YAML_ENV"], lines, "\n")
        in_rulesets = 0
      }
      /^rulesets:[[:space:]]*/ && updated == 0 {
        cr = (substr($0, length($0)) == "\r") ? "\r" : ""
        printf "rulesets:%s\n", cr
        for (i = 1; i <= count; i++) {
          printf "%s%s\n", lines[i], cr
        }
        updated = 1
        in_rulesets = 1
        next
      }
      in_rulesets == 1 && /^[[:space:]]+-[[:space:]]/ { next }
      in_rulesets == 1 && /^($|[[:space:]]|#)/ { print; next }
      in_rulesets == 1 { in_rulesets = 0 }
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
  if [[ "$FORCE" == "true" && "$BRANCH_SET" == "true" ]]; then
    if sync_existing_base_branch "$CSI_CONFIG"; then
      echo "   ✓ Updated base branch in: $CSI_CONFIG"
    else
      echo "   ⚠ Could not update base branch in: $CSI_CONFIG"
    fi
  fi
  if [[ "$FORCE" == "true" && "$RULESETS_SET" == "true" && ${#VALID_RULESETS[@]} -gt 0 ]]; then
    RULESETS_YAML=""
    for ruleset in "${VALID_RULESETS[@]}"; do
      RULESETS_YAML="${RULESETS_YAML:+${RULESETS_YAML}$'\n'}  - ${ruleset}"
    done
    if sync_existing_rulesets "$CSI_CONFIG" "$RULESETS_YAML"; then
      echo "   ✓ Updated rulesets in: $CSI_CONFIG"
    else
      echo "   ⚠ Could not update rulesets in: $CSI_CONFIG"
    fi
  fi
else
  echo ""
  echo "📋 Creating .csi.yml..."

  if [[ ! -f "$SCRIPT_DIR/.csi.yml" ]]; then
    echo "Error: Template .csi.yml not found at '$SCRIPT_DIR/.csi.yml'." >&2
    exit 1
  fi
  cp "$SCRIPT_DIR/.csi.yml" "$CSI_CONFIG"
  if ! sync_existing_schedule "$CSI_CONFIG"; then
    echo "   ⚠ Template .csi.yml missing 'schedule' key" >&2
    exit 1
  fi
  if ! sync_existing_base_branch "$CSI_CONFIG"; then
    echo "   ⚠ Template .csi.yml missing 'base_branch' key" >&2
    exit 1
  fi

  if [[ ${#VALID_RULESETS[@]} -gt 0 ]]; then
    RULESETS_YAML=""
    for ruleset in "${VALID_RULESETS[@]}"; do
      RULESETS_YAML="${RULESETS_YAML:+${RULESETS_YAML}$'\n'}  - ${ruleset}"
    done
    if ! sync_existing_rulesets "$CSI_CONFIG" "$RULESETS_YAML"; then
      echo "   ⚠ Template .csi.yml missing 'rulesets' key" >&2
      exit 1
    fi
  fi

  echo "   ✓ Created: $CSI_CONFIG"
fi

# ── Post-install instructions ─────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ CSI installed successfully!"
echo ""
echo "Next steps:"
echo ""
echo "  1. Add the COPILOT_TOKEN secret to your repository:"
echo "     Settings → Secrets and variables → Actions → New repository secret"
echo "     Name: COPILOT_TOKEN"
echo "     Value: A GitHub PAT with Copilot access"
echo ""
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
