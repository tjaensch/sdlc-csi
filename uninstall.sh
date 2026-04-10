#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# uninstall.sh — Remove CSI files from a repository
#
# Run with --help for usage and options.
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PATH="."
REMOVE_CONFIG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-path)
      shift; REPO_PATH="${1:?--repo-path requires a path argument}"; shift ;;
    --remove-config)
      REMOVE_CONFIG=true; shift ;;
    --help|-h)
      cat <<HELPEOF
Remove CSI (Continuous Self-Improvement) from a repository.

Removes the CSI workflow, agent, helper scripts, and bundled rulesets.
Preserves .csi.yml unless --remove-config is specified.

Usage:
  $(basename "$0") [OPTIONS]

Options:
  --repo-path <path>    Target repository root (default: current directory)
  --remove-config       Also remove .csi.yml
  --help                Show this help message
HELPEOF
      exit 0
      ;;
    *)
      echo "Error: Unknown argument '$1'. Use --help for usage." >&2
      exit 1
      ;;
  esac
done

REPO_PATH="$(cd "$REPO_PATH" && pwd)"

echo "🗑️  Removing CSI from: $REPO_PATH"
echo ""

remove_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    rm -f -- "$path"
    echo "   ✓ Removed: $path"
  fi
}

remove_installed_rulesets() {
  local rulesets_dir="$REPO_PATH/.github/rulesets"
  local bundled_rulesets_dir="$SCRIPT_DIR/rulesets"

  if [[ ! -d "$rulesets_dir" || ! -d "$bundled_rulesets_dir" ]]; then
    return 0
  fi

  local ruleset_name
  for ruleset_path in "$bundled_rulesets_dir"/*.md; do
    ruleset_name="$(basename "$ruleset_path")"
    remove_file "$rulesets_dir/$ruleset_name"
  done
}

remove_dir_if_empty() {
  local dir="$1"
  if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    rmdir "$dir"
    echo "   ✓ Removed empty directory: $dir"
  fi
}

# Remove installed files
remove_file "$REPO_PATH/.github/workflows/csi-run.yml"
remove_file "$REPO_PATH/.github/agents/csi-maintainer.agent.md"
remove_file "$REPO_PATH/.github/scripts/install-copilot-cli.sh"
remove_file "$REPO_PATH/.github/scripts/sanitize-report.sh"
remove_file "$REPO_PATH/.github/scripts/openai-scan.py"  # legacy cleanup

# Remove bundled rulesets without touching user-authored files
remove_installed_rulesets

# Optionally remove config
if [[ "$REMOVE_CONFIG" == "true" ]]; then
  remove_file "$REPO_PATH/.csi.yml"
else
  echo ""
  echo "   ℹ Preserved: .csi.yml (use --remove-config to also remove it)"
fi

# Clean up empty directories
remove_dir_if_empty "$REPO_PATH/.github/agents"
remove_dir_if_empty "$REPO_PATH/.github/scripts"
remove_dir_if_empty "$REPO_PATH/.github/rulesets"

echo ""
echo "✅ CSI uninstalled."
