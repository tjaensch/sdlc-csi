# Rust Ruleset — Rust Best Practices

Activate by adding `rust` to the `rulesets` list in `.csi.yml`.

## Rules

### RS-001: Run `clippy` in CI
CI pipelines should run `cargo clippy -- -D warnings` to catch common mistakes and enforce idiomatic Rust.

### RS-002: No `unwrap()` in library/production code
Use `?` operator, `expect()` with a descriptive message, or proper error handling instead of bare `unwrap()` in non-test code.

### RS-003: `Cargo.lock` should be committed for binaries
Binary crates should commit `Cargo.lock` for reproducible builds. Library crates may omit it.

### RS-004: Use `thiserror` or custom error types
Libraries should define structured error types (via `thiserror` or manual `impl`) instead of returning `Box<dyn Error>` or string errors.

### RS-005: Prefer `&str` over `String` in function parameters
Functions that only read a string should accept `&str` (or `impl AsRef<str>`) rather than requiring an owned `String`.

### RS-006: No `unsafe` without a `// SAFETY:` comment
Every `unsafe` block must have a comment explaining why it is sound.

### RS-007: `target/` must be gitignored
The `target/` build directory must appear in `.gitignore`.

### RS-008: Use `#[must_use]` on functions returning values
Functions whose return value should not be ignored (especially `Result`) should be annotated with `#[must_use]`.

### RS-009: Minimize feature flags
`Cargo.toml` features should be minimal and documented. Avoid feature flags that are always on or never tested in CI.

### RS-010: Add doc comments to public API
All `pub` items should have `///` doc comments. Run `cargo doc --no-deps` in CI to catch broken doc links.
