# CSI Setup Guide — Prerequisites & Configuration

This guide walks you through everything needed to get CSI running in your repository. Follow the steps in order.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install CSI](#2-install-csi)
3. [Configure the Copilot Token](#3-configure-the-copilot-token)
4. [Enable PR Creation](#4-enable-pr-creation)
5. [Optional: Enable Workflow File Edits](#5-optional-enable-workflow-file-edits)
6. [Optional: Enable Auto-Delete of Merged Branches](#6-optional-enable-auto-delete-of-merged-branches)
7. [Configure .csi.yml](#7-configure-csiyml)
8. [Commit and Verify](#8-commit-and-verify)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites

Before installing CSI, make sure you have:

- [ ] A **GitHub repository** (public or private)
- [ ] **Git** installed locally
- [ ] **GitHub CLI** (`gh`) installed — [install guide](https://cli.github.com/)
- [ ] A GitHub account with **Copilot access**
- [ ] Repository **admin access** (needed for settings and secrets)

### Verify your tools

```bash
git --version     # any recent version
gh --version      # 2.x or later
gh auth status    # must be authenticated
```

---

## 2. Install CSI

Clone the CSI repo and run the installer:

```bash
git clone https://github.com/tjaensch/csi.git
bash csi/install.sh --repo-path /path/to/your-repo
```

This copies the following into your repo:
- `.github/workflows/csi-run.yml` — the main workflow
- `.github/agents/csi-maintainer.agent.md` — the agent definition
- `.github/scripts/` — helper scripts (Copilot CLI installer, sanitizer)
- `.github/rulesets/generic.md` — the base ruleset (always active)
- `.csi.yml` — configuration file (created only if it doesn't exist)

### Installer options

| Flag | Description | Default |
|------|-------------|---------|
| `--repo-path <path>` | Target repository root | Current directory |
| `--rulesets <list>` | Comma-separated rulesets to install | `generic` only |
| `--branch <name>` | Base branch for PRs | `main` |
| `--schedule <cron>` | Cron schedule | `0 10 * * 1` (Monday 10:00 UTC) |
| `--force` | Overwrite existing CSI files | Off |

### Example with rulesets

```bash
bash csi/install.sh \
  --repo-path /path/to/your-repo \
  --rulesets "python,bash,docker" \
  --schedule "0 8 * * *"
```

---

## 3. Configure the Copilot Token

CSI uses GitHub Copilot to scan and apply fixes.

**Step 1: Create a Personal Access Token (PAT)**

1. Go to [github.com](https://github.com) → click your **profile avatar** (top right) → **Settings**
2. In the left sidebar, scroll to the bottom → **Developer settings**
3. Click **Personal access tokens** → **Fine-grained tokens** → **Generate new token**
4. Fill in:
   - **Token name**: `CSI - Copilot Token`
   - **Expiration**: 90 days (you'll need to rotate periodically)
   - **Resource owner**: your GitHub account
   - **Repository access**: **Only select repositories** → pick your target repo(s)
5. Under **Permissions → Account permissions**:
   - **GitHub Copilot**: **Read** (if available)
6. Click **Generate token** and **copy the value immediately** (you won't see it again)

**Step 2: Add the secret to your repo**

1. Go to your repo on GitHub → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `COPILOT_TOKEN`
4. Secret: paste the token you copied
5. Click **Add secret**

---

## 4. Enable PR Creation

GitHub Actions requires explicit permission to create pull requests.

1. Go to your repo → **Settings** → **Actions** → **General**
2. Scroll down to the **Workflow permissions** section
3. Check **"Allow GitHub Actions to create and approve pull requests"**
4. Click **Save**

> **Without this setting**, the workflow will complete successfully but fail at the PR creation step with: `GraphQL: GitHub Actions is not permitted to create or approve pull requests`

---

## 5. Optional: Enable Workflow File Edits

By default, `GITHUB_TOKEN` is blocked by GitHub from pushing changes to `.github/workflows/` files. This is a platform-level security restriction that cannot be overridden by permissions.

If you want CSI to be able to fix issues in workflow files:

**Step 1: Create a fine-grained PAT with workflow scope**

1. Go to [github.com](https://github.com) → **profile avatar** → **Settings** → **Developer settings**
2. **Personal access tokens** → **Fine-grained tokens** → **Generate new token**
3. Fill in:
   - **Token name**: `CSI - Workflow PAT`
   - **Expiration**: 90 days
   - **Repository access**: **Only select repositories** → pick your target repo(s)
4. Under **Permissions → Repository permissions**, set:
   - **Contents**: **Read and write**
   - **Pull requests**: **Read and write**
   - **Workflows**: **Read and write**
5. Click **Generate token** and copy the value

**Step 2: Add as repo secret**

1. Go to your repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `CSI_PAT`
4. Secret: paste the PAT
5. Click **Add secret**

CSI auto-detects `CSI_PAT` at runtime. When present:
- Workflow files are included in commits and PRs
- The agent is allowed to edit `.github/workflows/` files
- The PAT is used for push and PR creation

When absent, CSI falls back to `GITHUB_TOKEN` with workflow files excluded. The workflow emits a notice indicating which mode is active.

---

## 6. Optional: Enable Auto-Delete of Merged Branches

CSI creates a branch for each PR (e.g., `csi/fix-2026-04-08`). To clean them up automatically:

1. Go to your repo → **Settings** → **General**
2. Scroll to the **Pull Requests** section
3. Check **"Automatically delete head branches"**

This applies to all merged PRs, not just CSI.

---

## 7. Configure .csi.yml

The installer creates a default `.csi.yml`. For a fully documented reference configuration with all available options and their defaults, see [`examples/.csi.yml`](../examples/.csi.yml).

Here's a fully annotated example:

```yaml
version: 1

# Cron schedule (UTC). Default: weekly Monday at 10:00.
schedule: "0 10 * * 1"

# Base branch for PRs
base_branch: main

# Days before stale CSI PRs are auto-closed
stale_pr_days: 3

# Override the model. Leave empty to auto-select from the
# workflow's preference list (tries models in order until one works).
# model: "gpt-5.4"

# Scan timeout in seconds
timeout: 1800

# Toggle scan categories on/off
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

  # Glob patterns to exclude from scanning
  exclude_paths:
    - "vendor/**"
    - "node_modules/**"
    - "dist/**"
    - ".git/**"

# Language-specific rulesets (must be installed in .github/rulesets/)
rulesets:
  - python
  - bash

# Custom rules (free-text, checked in addition to rulesets)
# custom_rules:
#   - "All API endpoints must have OpenAPI documentation"
#   - "Database migrations must be reversible"
```

### Scan categories explained

| Category | What it checks |
|----------|---------------|
| `dry_violations` | Duplicated logic across files, scripts, configs |
| `documentation_drift` | README referencing deleted files, outdated setup instructions |
| `tooling_currency` | Outdated CI actions, deprecated runtime versions |
| `dead_code` | Unused scripts, orphaned config files, unreferenced imports |
| `code_quality` | Broad `except` blocks, missing error handling, code smells |
| `security_hygiene` | Committed secrets, overly broad permissions, missing `.gitignore` patterns |
| `dependency_health` | Unpinned dependencies, known vulnerable packages |
| `config_consistency` | Mismatched settings between config files, env files, docs |

---

## 8. Commit and Verify

### Push the installed files

```bash
cd /path/to/your-repo
git add .csi.yml .github/
git commit -m "chore: install CSI automated maintenance"
git push
```

### Run a dry run first

A dry run scans and reports without creating a PR:

```bash
gh workflow run csi-run.yml -f dry_run=true
```

Watch it at: `https://github.com/<owner>/<repo>/actions`

### Verify the dry run

Check the workflow run for:
- **"Detect push token"** step — confirms whether `CSI_PAT` was detected
- **"Run CSI scan"** step — should show which model was used
- **Job summary** — the scan report appears at the bottom

### Trigger a full run

Once the dry run looks good:

```bash
gh workflow run csi-run.yml
```

This will scan, apply one fix, and open a PR.

---

## 9. Troubleshooting

### "GraphQL: GitHub Actions is not permitted to create or approve pull requests"

→ Enable PR creation in repo settings. See [Step 4](#4-enable-pr-creation).

### "COPILOT_TOKEN secret is empty or not set"

→ Add the `COPILOT_TOKEN` secret to your repo. See [Step 3](#3-configure-the-copilot-token).

### PR is created but doesn't contain workflow file changes

→ You need `CSI_PAT` for workflow file edits. See [Step 5](#5-optional-enable-workflow-file-edits).

### "No files were changed. Repository is in good health."

→ CSI found no issues to fix. This is expected for well-maintained repos. Check the job summary for the full scan report.

### Scan produces empty output or times out

Possible causes:
- The model may be unavailable. CSI tries models in order from its preference list.
- The timeout may be too short for large repos. Increase `timeout` in `.csi.yml`.
- Check the workflow logs for specific error messages.

### PAT expired

Fine-grained PATs have an expiration date. When they expire:
1. Generate a new token (same steps as before)
2. Update the secret in your repo settings
3. The next run will use the new token automatically
