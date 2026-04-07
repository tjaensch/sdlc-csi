#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# uninstall.sh — Remove CSI files from a repository
# ────────────────────────────────────────────────────────────────────────────
# Removes the CSI workflow, agent, and helper scripts. Preserves .csi.yml
# (your configuration) unless --remove-config is specified.
#
# Usage:
#   ./uninstall.sh [OPTIONS]
#
# Options:
#   --repo-path <path>    Target repository root (default: current directory)
#   --remove-config       Also remove .csi.yml
#   --help                Show this help message
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_PATH="."
REMOVE_CONFIG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-path)
      shift; REPO_PATH="${1:?--repo-path requires a path argument}"; shift ;;
    --remove-config)
      REMOVE_CONFIG=true; shift ;;
    --help|-h)
      head -15 "$0" | tail -10
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
    rm "$path"
    echo "   ✓ Removed: $path"
  fi
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
remove_file "$REPO_PATH/.github/scripts/openai-scan.py"

# Remove rulesets
if [[ -d "$REPO_PATH/.github/rulesets" ]]; then
  rm -rf "$REPO_PATH/.github/rulesets"
  echo "   ✓ Removed: $REPO_PATH/.github/rulesets/"
fi

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

echo ""
echo "✅ CSI uninstalled."
