# CSI — Continuous Self-Improvement

Automated repository health scanning and maintenance for any codebase. CSI uses an LLM-powered agent to scan your repository on a recurring schedule, identify maintenance issues across 8 categories, apply one targeted fix per run, and open a pull request — keeping your codebase healthy with minimal human effort.

## How It Works

```
Weekly Schedule (or manual trigger)
    │
    ▼
┌─────────────────────────────────┐
│  CSI Workflow (.github/actions) │
│                                 │
│  1. Read .csi.yml config        │
│  2. Build agent prompt          │
│     + enabled rulesets          │
│  3. Run LLM scan (Copilot/     │
│     OpenAI)                     │
│  4. Apply ONE fix               │
│  5. Open PR with report         │
└─────────────────────────────────┘
    │
    ▼
Small, reviewable PR with:
  • What was fixed and why
  • Evidence (file paths, line numbers)
  • Remaining issues for future runs
```

Each run produces **one focused fix** to keep PRs small and reviewable. Stale PRs are automatically closed after a configurable number of days.

## Quick Start

### 1. Install

```bash
# Clone CSI
git clone https://github.com/tjaensch/csi.git

# Install into your project
bash csi/install.sh --repo-path /path/to/your-repo

# With language-specific rulesets
bash csi/install.sh --repo-path /path/to/your-repo --rulesets "python,javascript"
```

### 2. Add a Secret

CSI needs an LLM backend. Choose one:

**GitHub Copilot (recommended — full scan + auto-fix):**
- Go to your repo → Settings → Secrets → Actions → New repository secret
- Name: `COPILOT_TOKEN`
- Value: A GitHub PAT with Copilot access

**OpenAI (scan-only, no auto-fix):**
- Name: `OPENAI_API_KEY`
- Value: Your OpenAI API key
- Set `backend: openai` in `.csi.yml`

### 3. Commit and Run

```bash
git add .csi.yml .github/
git commit -m "chore: install CSI automated maintenance"
git push

# Trigger a dry run
gh workflow run csi-run.yml -f dry_run=true
```

## What It Scans

| Category | Examples |
|----------|----------|
| **DRY Violations** | Duplicated shell blocks across workflows, copy-pasted functions |
| **Documentation Drift** | README referencing deleted files, outdated setup instructions |
| **Tooling Currency** | GitHub Actions pinned to old versions, outdated runtime versions |
| **Dead Code** | Unused scripts, unreferenced config files, stale imports |
| **Code Quality** | Bare except blocks, magic numbers, missing error handling at boundaries |
| **Security Hygiene** | Hardcoded secrets, committed `.env` files, missing `.gitignore` patterns |
| **Dependency Health** | Unpinned versions, deprecated packages, missing lockfiles |
| **Config Consistency** | Build configs referencing non-existent files, environment mismatches |

## Configuration

CSI is configured via a `.csi.yml` file in your repository root. The installer creates one with sensible defaults.

```yaml
version: 1

# Schedule: weekly Monday 10:00 UTC (cron syntax)
schedule: "0 10 * * 1"

# Branch to base fix PRs on
base_branch: main

# Auto-close unmerged PRs after N days
stale_pr_days: 3

# LLM backend: "copilot" (scan + fix) or "openai" (scan only)
backend: copilot

# Override model (empty = default routing)
model: ""

# Scan timeout in seconds
timeout: 900

# Toggle scan categories
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

# Language-specific rule packs (see "Rulesets" below)
rulesets: []

# Repo-specific rules (free text)
custom_rules: []
```

### Configuration Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `version` | int | `1` | Config schema version |
| `schedule` | string | `"0 10 * * 1"` | Cron expression (UTC) for scheduled scans |
| `base_branch` | string | `"main"` | Branch to base fix PRs on |
| `stale_pr_days` | int | `3` | Days before unmerged PRs are auto-closed |
| `backend` | string | `"copilot"` | `"copilot"` or `"openai"` |
| `model` | string | `""` | LLM model override |
| `timeout` | int | `900` | Scan timeout in seconds |
| `scan.categories.*` | bool | `true` | Enable/disable individual scan categories |
| `scan.exclude_paths` | list | common vendors | Glob patterns to skip during scanning |
| `rulesets` | list | `[]` | Language rule packs to enable |
| `custom_rules` | list | `[]` | Free-text repo-specific rules |

## Rulesets

Rulesets are language-aware rule packs that extend the base scan with framework-specific checks. Enable them in `.csi.yml`:

```yaml
rulesets:
  - python
  - javascript
```

### Available Rulesets

| Ruleset | Language | Example Rules |
|---------|----------|---------------|
| `generic` | Any | README exists, no committed secrets, pinned CI actions *(always active)* |
| `python` | Python | Type hints on public functions, no bare `except:`, use `pathlib` |
| `javascript` | JS/TS | Lockfile committed, no `console.log` in prod, strict TypeScript |
| `java` | Java | Try-with-resources, SLF4J over `println`, pin Maven/Gradle versions |
| `go` | Go | Handle all errors, `go.sum` committed, no `panic` in libraries |
| `rust` | Rust | No `unwrap()` in prod, `clippy` in CI, `// SAFETY:` on `unsafe` |
| `ruby` | Ruby | `frozen_string_literal`, no `rescue Exception`, RuboCop in CI |
| `kotlin` | Kotlin | `val` over `var`, no `!!` in prod, sealed classes for state |
| `swift` | Swift | No force unwrapping, `guard` for early exits, SwiftLint in CI |
| `php` | PHP | `strict_types`, no `eval()`, prepared statements for DB access |
| `terraform` | HCL | Pin provider versions, no secrets in `.tf`, use modules |
| `docker` | Docker | Pin base image tags, multi-stage builds, no secrets in images |
| `dotnet` | C#/.NET | Nullable enabled, no secrets in `appsettings.json`, async naming |
| `nextflow` | Nextflow | DSL2 syntax, container tags pinned, `meta.yml` exists |

### Adding Custom Rulesets

Create a markdown file in `.github/rulesets/` in your repo and reference it by name:

```yaml
rulesets:
  - python
  - my-custom-rules   # reads .github/rulesets/my-custom-rules.md
```

Follow the pattern in existing rulesets under `rulesets/` — use `<LANG>-NNN` IDs, short titles, and actionable descriptions.

## Backends

### GitHub Copilot (recommended)

- Full scan **and** auto-fix — the agent can edit files and create PRs
- Requires `COPILOT_TOKEN` secret (GitHub PAT with Copilot access)
- Uses the [Copilot CLI](https://github.com/github/copilot-cli) under the hood

### OpenAI

- **Scan-only** — generates a report but cannot edit files
- Requires `OPENAI_API_KEY` secret
- Useful for getting a health report without automated changes
- Default model: `gpt-4o` (configurable via `model` field)

## Installer Options

```
./install.sh [OPTIONS]

Options:
  --repo-path <path>       Target repository (default: current directory)
  --rulesets <list>         Comma-separated rulesets to enable
  --backend <name>          "copilot" or "openai" (default: copilot)
  --branch <name>           Base branch for PRs (default: main)
  --schedule <cron>         Scan schedule (default: "0 10 * * 1")
  --force                   Overwrite existing CSI files (except .csi.yml)
  --help                    Show help
```

The installer is **idempotent** — re-running updates CSI files but never overwrites your `.csi.yml` configuration.

## Uninstalling

```bash
bash csi/uninstall.sh --repo-path /path/to/your-repo

# Also remove .csi.yml
bash csi/uninstall.sh --repo-path /path/to/your-repo --remove-config
```

## Security Model

CSI is designed with defense-in-depth:

- **Isolated authentication** — LLM credentials are scoped to the scan step via an isolated config directory and are not persisted
- **Report sanitization** — All tokens, API keys, and auth headers are automatically redacted before appearing in PR descriptions or job summaries
- **Workflow file protection** — Changes to `.github/workflows/` are excluded from commits (GITHUB_TOKEN cannot push workflow changes)
- **Safety constraints** — The agent is instructed to never delete files without replacement, never modify secrets/triggers/permissions, and keep all changes backward-compatible
- **Stale PR cleanup** — Unmerged PRs are automatically closed to prevent clutter

### Required Permissions

The workflow needs these GitHub token permissions:
- `contents: write` — push fix branches
- `pull-requests: write` — create/close PRs
- `issues: write` — create labels

## Manual Trigger

You can trigger a scan manually via the GitHub Actions UI or CLI:

```bash
# Dry run (scan only, no PR)
gh workflow run csi-run.yml -f dry_run=true

# Full scan and fix
gh workflow run csi-run.yml

# With a specific model
gh workflow run csi-run.yml -f model=gpt-4o
```

## FAQ

**Q: How often should I run CSI?**
Weekly is a good default for most repos. High-activity repos might benefit from daily scans. Set the `schedule` in `.csi.yml`.

**Q: Will CSI break my code?**
CSI applies one minimal fix per run and opens a PR for human review. It never pushes directly to your default branch. All changes are backward-compatible by design.

**Q: Can I use CSI on private repos?**
Yes. The Copilot backend requires a PAT with appropriate access. The OpenAI backend works with any repo since it reads files locally in the runner.

**Q: What if the fix is wrong?**
Close the PR. CSI will re-evaluate the issue in a future run. You can also add `custom_rules` to guide the agent's behavior.

**Q: Can I disable specific scan categories?**
Yes. Set any category to `false` in `.csi.yml` under `scan.categories`.

## License

[MIT](LICENSE)
