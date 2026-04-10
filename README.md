# CSI — Continuous Self-Improvement

Automated repository health scanning and maintenance for any codebase. CSI uses an LLM-powered agent to scan your repository on a recurring schedule, identify maintenance issues across 8 categories, apply one targeted fix per run, and open a pull request — keeping your codebase healthy with minimal human effort.

## How It Works

```
Weekly Schedule (or manual trigger)
    │
    ▼
┌─────────────────────────────────┐
│  CSI Workflow (.github/workflows)│
│                                 │
│  1. Read .csi.yml config        │
│  2. Build agent prompt          │
│     + enabled rulesets          │
│  3. Run LLM scan (Copilot)     │
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

```bash
# 1. Clone CSI and install into your project
git clone https://github.com/tjaensch/csi.git
bash csi/install.sh --repo-path /path/to/your-repo --rulesets "python,javascript"

# 2. Add a COPILOT_TOKEN secret to your repo:
#    Settings → Secrets and variables → Actions → New repository secret
#    Name: COPILOT_TOKEN  |  Value: a GitHub PAT with Copilot access

# 3. Enable PR creation:
#    Settings → Actions → General → Workflow permissions
#    → Check "Allow GitHub Actions to create and approve pull requests"

# 4. Commit and run
git add .csi.yml .github/
git commit -m "chore: install CSI automated maintenance"
git push

gh workflow run csi-run.yml -f dry_run=true   # scan only (no PR)
gh workflow run csi-run.yml                    # scan + fix + open PR
```

> **Need more detail?** The full [Setup Guide](docs/SETUP.md) covers token creation, workflow file permissions, troubleshooting, and all configuration options.

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

CSI is configured via `.csi.yml` in your repository root. The installer creates one with sensible defaults — most users won't need to change anything.

```yaml
version: 1
schedule: "0 10 * * 1"        # weekly Monday 10:00 UTC
base_branch: main
rulesets:
  - python
  - javascript
```

See the [Configuration Reference](docs/SETUP.md#7-configure-csiyml) and [`examples/.csi.yml`](examples/.csi.yml) for all available options.

## Available Rulesets

Rulesets are language-aware rule packs that extend the base scan. Enable them in `.csi.yml` or via `--rulesets` during install. The `generic` ruleset is always active.

<details>
<summary><strong>View all 19 rulesets</strong></summary>

| Ruleset | Language | Example Rules |
|---------|----------|---------------|
| `generic` | Any | README exists, no committed secrets, pinned CI actions *(always active)* |
| `bash` | Bash/Shell | `set -euo pipefail`, quote variables, `mktemp` for temp files |
| `docker` | Docker | Pin base image tags, multi-stage builds, no secrets in images |
| `dotnet` | C#/.NET | Nullable enabled, no secrets in `appsettings.json`, async naming |
| `go` | Go | Handle all errors, `go.sum` committed, no `panic` in libraries |
| `java` | Java | Try-with-resources, SLF4J over `println`, pin Maven/Gradle versions |
| `javascript` | JavaScript | Lockfile committed, no `console.log` in prod, pin Node.js version |
| `kotlin` | Kotlin | `val` over `var`, no `!!` in prod, sealed classes for state |
| `kubernetes` | K8s/Helm | Resource limits, liveness probes, no `latest` tags, non-root containers |
| `nextflow` | Nextflow | DSL2 syntax, container tags pinned, `meta.yml` exists |
| `php` | PHP | `strict_types`, no `eval()`, prepared statements for DB access |
| `powershell` | PowerShell | `$ErrorActionPreference = 'Stop'`, no aliases in scripts, PSScriptAnalyzer |
| `python` | Python | Type hints on public functions, no bare `except:`, use `pathlib` |
| `ruby` | Ruby | `frozen_string_literal`, no `rescue Exception`, RuboCop in CI |
| `rust` | Rust | No `unwrap()` in prod, `clippy` in CI, `// SAFETY:` on `unsafe` |
| `sql` | SQL | No `SELECT *`, explicit `JOIN` syntax, CTEs over nested subqueries |
| `swift` | Swift | No force unwrapping, `guard` for early exits, SwiftLint in CI |
| `terraform` | HCL | Pin provider versions, no secrets in `.tf`, use modules |
| `typescript` | TypeScript | Strict mode, no `any`, explicit return types, no `@ts-ignore` |

</details>

You can also [create custom rulesets](docs/SETUP.md#7-configure-csiyml) by adding a markdown file to `.github/rulesets/` in your repo and listing its name in `.csi.yml`:

```yaml
rulesets:
  - python
  - my-custom-rules   # loads .github/rulesets/my-custom-rules.md
```

## Uninstalling

```bash
bash csi/uninstall.sh --repo-path /path/to/your-repo
bash csi/uninstall.sh --repo-path /path/to/your-repo --remove-config  # also remove .csi.yml
```

## Security

- LLM credentials are scoped to the scan step and never persisted
- All tokens and secrets are redacted from PR descriptions and job summaries
- The agent never deletes files, modifies secrets/triggers, or changes permissions
- Stale PRs are auto-closed after a configurable number of days
- Workflow file edits require an explicit `CSI_PAT` opt-in

See the [Setup Guide](docs/SETUP.md) for details on permissions and token scoping.

## ⚠️ Disclaimer

CSI uses LLM-generated analysis and code changes. LLM output **can be wrong, incomplete, or misleading** — including hallucinated file paths, incorrect fixes, or missed issues. All generated PRs **must be reviewed by a human** before merging. CSI is a maintenance assistant, not a substitute for developer judgment.

## FAQ

**Q: How often should I run CSI?**
Weekly is a good default for most repos. High-activity repos might benefit from daily scans. Update the `schedule` in `.csi.yml`, then re-run `install.sh --schedule "..." --force` or edit `.github/workflows/csi-run.yml` to sync the workflow cron.

**Q: Will CSI break my code?**
CSI applies one minimal fix per run and opens a PR for human review. It never pushes directly to your default branch. All changes are backward-compatible by design.

**Q: Can I use CSI on private repos?**
Yes. The Copilot backend requires a PAT with appropriate access.

**Q: What if the fix is wrong?**
Close the PR. CSI will re-evaluate the issue in a future run. You can also add `custom_rules` to guide the agent's behavior.

**Q: Can I disable specific scan categories?**
Yes. Set any category to `false` in `.csi.yml` under `scan.categories`.

## License

[MIT](LICENSE)
