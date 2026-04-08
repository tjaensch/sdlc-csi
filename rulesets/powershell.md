# PowerShell Ruleset — PowerShell Script Best Practices

Activate by adding `powershell` to the `rulesets` list in `.csi.yml`.

## Rules

### PS-001: Use approved verbs for function names
Functions should use approved PowerShell verbs (`Get-Verb` output) in their names, e.g., `Get-UserData` not `Fetch-UserData`.

### PS-002: Set `$ErrorActionPreference = 'Stop'`
Scripts should set `$ErrorActionPreference = 'Stop'` to halt on errors instead of silently continuing. Use `try/catch` for explicit error handling.

### PS-003: Use `[CmdletBinding()]` on functions
Functions should include `[CmdletBinding()]` to enable common parameters like `-Verbose`, `-Debug`, and `-ErrorAction`.

### PS-004: No `Write-Host` for output — use `Write-Output` or `Write-Verbose`
`Write-Host` bypasses the pipeline and cannot be captured or redirected. Use `Write-Output` for data and `Write-Verbose` for diagnostics.

### PS-005: Use `param()` blocks instead of `$args`
Functions and scripts should declare parameters with `param()` blocks (with types) instead of relying on `$args`.

### PS-006: No aliases in scripts
Aliases like `%`, `?`, `select`, `where` should not be used in scripts — use full cmdlet names (`ForEach-Object`, `Where-Object`, `Select-Object`) for readability.

### PS-007: Use `Join-Path` instead of string concatenation for paths
Path construction should use `Join-Path` or `[System.IO.Path]::Combine()` instead of string concatenation with `\` or `/`.

### PS-008: No plaintext credentials in scripts
Credentials should use `Get-Credential`, `SecureString`, or environment variables — never hardcoded plaintext passwords.

### PS-009: Use `#Requires` for dependencies
Scripts should declare prerequisites with `#Requires -Version`, `#Requires -Modules`, or `#Requires -RunAsAdministrator` instead of runtime checks.

### PS-010: PSScriptAnalyzer compliance
Scripts should pass `Invoke-ScriptAnalyzer` without errors. If available in CI, it should be run on all `.ps1` and `.psm1` files.
