# Examples

This directory contains example configurations for CSI.

## `.csi.yml`

The [`.csi.yml`](.csi.yml) file shows a fully documented configuration with all available options and their defaults. Copy it to your repository root and customize as needed.

## Example: Python Project

```yaml
version: 1
schedule: "0 10 * * 1"
base_branch: main
stale_pr_days: 3
backend: copilot
timeout: 900

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
    - ".venv/**"
    - "dist/**"
    - "*.egg-info/**"

rulesets:
  - python

custom_rules:
  - "All public functions must have docstrings"
  - "Use pytest instead of unittest"
```

## Example: Node.js / TypeScript Project

```yaml
version: 1
schedule: "0 10 * * 1"
base_branch: main
backend: copilot

scan:
  exclude_paths:
    - "node_modules/**"
    - "dist/**"
    - "coverage/**"

rulesets:
  - javascript

custom_rules:
  - "All React components must be functional, not class-based"
```

## Example: OpenAI Backend (Scan-Only)

```yaml
version: 1
schedule: "0 10 * * 1"
base_branch: main
backend: openai
model: "gpt-4o"

scan:
  categories:
    security_hygiene: true
    dependency_health: true
    code_quality: true
    # Disable categories that benefit more from auto-fix
    dry_violations: false
    dead_code: false
```
