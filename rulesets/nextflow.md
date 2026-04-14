# Nextflow Ruleset — Nextflow DSL2 / nf-core Best Practices

Activate by adding `nextflow` to the `rulesets` list in `.csi.yml`.

## Rules

### NF-001: Use DSL2 syntax
All `.nf` files should use DSL2 (`nextflow.enable.dsl = 2`). Legacy DSL1 process syntax should be migrated.

### NF-002: Processes should define resource labels or requirements
Every process must specify `cpus`, `memory`, and `time` directives — either directly or through labels defined in a config.

### NF-003: Container directives should specify exact tags
`container` directives should use a specific image tag (e.g., `quay.io/org/tool:1.2.3`), never `:latest`.

### NF-004: Module `meta.yml` must exist
Every module under `modules/` should have a `meta.yml` describing inputs, outputs, and tools.

### NF-005: Publish directory should use `params`
`publishDir` should reference `params.outdir` rather than hardcoded paths.

### NF-006: Channel operators should use modern syntax
Prefer `.map{}`, `.filter{}`, `.collect()` over legacy operators like `into` and `subscribe`. Note: `.set{}` is valid DSL2 syntax for naming channels.

### NF-007: `modules.json` should track installed modules
All nf-core modules should be registered in `modules.json` for reproducibility and update tracking.

### NF-008: Test profiles should exist
`nextflow.config` should define `test` and `test_full` profiles under the `profiles` scope.

### NF-009: `nextflow_schema.json` should match params
Parameters declared in `nextflow.config` should have corresponding entries in `nextflow_schema.json`.

### NF-010: Workflow should validate required params
The main workflow should validate required parameters early and produce clear error messages on missing input.
