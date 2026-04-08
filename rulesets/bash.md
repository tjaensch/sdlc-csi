# Bash Ruleset — Shell Script Best Practices

Activate by adding `bash` to the `rulesets` list in `.csi.yml`.

## Rules

### BASH-001: Scripts must start with a shebang
Every shell script should start with `#!/usr/bin/env bash` (or `#!/bin/bash`). Scripts without a shebang may execute under an unexpected shell.

### BASH-002: Use `set -euo pipefail`
Scripts should include `set -euo pipefail` near the top to fail on errors (`-e`), unset variables (`-u`), and broken pipes (`-o pipefail`).

### BASH-003: Quote all variable expansions
Variables should be double-quoted (`"$var"`, `"${array[@]}"`) to prevent word splitting and globbing. Exceptions: inside `[[ ]]` conditions and arithmetic `(( ))` contexts.

### BASH-004: Use `[[ ]]` instead of `[ ]` for conditionals
`[[ ]]` is safer and more feature-rich than `[ ]` — it handles empty variables, supports regex, and doesn't require quoting inside the brackets.

### BASH-005: Use `$()` instead of backticks for command substitution
Backtick syntax `` `cmd` `` is error-prone with nesting. Use `$(cmd)` for command substitution.

### BASH-006: No `eval` or unquoted variable expansion in commands
`eval "$user_input"` and unquoted expansions in command positions are injection risks. Use arrays for dynamic command construction instead.

### BASH-007: Use `local` for function variables
Variables declared inside functions should use `local` to avoid polluting the global namespace.

### BASH-008: Use `mktemp` for temporary files
Temporary files should be created with `mktemp` (not hardcoded paths like `/tmp/myfile`). Clean up with a `trap` on `EXIT`.

### BASH-009: No `cd` without error handling
`cd some/dir` should be followed by `|| exit 1` (or use `set -e`). Alternatively, use `pushd`/`popd` for directory stack management.

### BASH-010: ShellCheck compliance
Scripts should pass `shellcheck` without errors. If ShellCheck is available in CI, it should be run on all `.sh` and `.bash` files.
