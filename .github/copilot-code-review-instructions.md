# Copilot Code Review Instructions

## Review focus

Prioritize comments about:

- **Bugs**: Logic errors, incorrect behavior, broken control flow
- **Security**: Injection, credential exposure, unsafe input handling
- **Correctness**: Wrong return values, off-by-one errors, race conditions
- **Data loss**: Destructive operations without safeguards

## Out of scope

Do not comment on:

- Speculative edge cases that require unlikely preconditions (e.g., non-standard YAML indentation, users intentionally passing only invalid inputs)
- Robustness suggestions for scenarios that cannot occur given the current code paths
- Style preferences, naming conventions, or minor refactors that don't affect correctness
- Suggestions to add error handling for conditions already guarded upstream
- Repeating or rephrasing a comment that was already made in a prior review round

## Shell scripts

This project heavily uses bash scripts with `set -euo pipefail`. When reviewing:

- Do not suggest adding error handling for operations that will already fail under `set -e`
- Do not flag portable-shell concerns — the project targets bash 4+ on Linux/macOS only
- Focus on actual failure modes, not theoretical ones
