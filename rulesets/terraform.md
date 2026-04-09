# Terraform / HCL Ruleset — Infrastructure-as-Code Best Practices

Activate by adding `terraform` to the `rulesets` list in `.csi.yml`.

## Rules

### TF-001: Pin provider versions
`required_providers` in `terraform` block should pin versions with `~>` constraints, never leave them unpinned.

### TF-002: Pin Terraform version
The `required_version` field should be set in the `terraform` block to prevent drift across team members.

### TF-003: Use `terraform fmt` in CI
CI pipelines should run `terraform fmt -check` to enforce consistent formatting.

### TF-004: Use `terraform validate` in CI
CI should run `terraform validate` to catch syntax and reference errors before plan/apply.

### TF-005: No hardcoded secrets in `.tf` files
Sensitive values (passwords, keys, connection strings) must use `var` with `sensitive = true` or be sourced from a secret manager. Never hardcode in `.tf` or `.tfvars`.

### TF-006: `.terraform/` and `*.tfstate` must be gitignored
Local state files and the `.terraform/` plugin cache must appear in `.gitignore`. Use remote state backends.

### TF-007: Use `description` on all variables and outputs
Every `variable` and `output` block should have a `description` field for documentation and `terraform docs` generation.

### TF-008: Use modules for repeated patterns
Repeated resource patterns (e.g., identical VPCs, storage accounts) should be extracted into reusable modules.

### TF-009: Name resources with consistent conventions
Resource names should follow a consistent pattern (e.g., `<project>-<env>-<resource>`) and use underscores in Terraform identifiers.

### TF-010: Use `locals` to reduce duplication
Repeated expressions or computed values should be defined in `locals` blocks rather than duplicated across resources.
