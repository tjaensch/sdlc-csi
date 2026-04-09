# Go Ruleset — Go Best Practices

Activate by adding `go` to the `rulesets` list in `.csi.yml`.

## Rules

### GO-001: Run `go vet` and `staticcheck` in CI
CI pipelines should run `go vet` and ideally `staticcheck` or `golangci-lint` to catch common bugs before merge.

### GO-002: Handle all errors
Every returned `error` must be checked. Avoid `_` for error values unless there is a documented reason (e.g., `fmt.Fprintf` to stdout).

### GO-003: Use `context.Context` for cancellation
Functions that perform I/O, network calls, or long-running work should accept `context.Context` as the first parameter.

### GO-004: No `init()` functions unless necessary
`init()` functions make code harder to test and reason about. Prefer explicit initialization in `main()` or constructors.

### GO-005: `go.sum` must be committed
Both `go.mod` and `go.sum` should be committed for reproducible builds.

### GO-006: Prefer `errors.Is` / `errors.As` over `==`
Use `errors.Is()` and `errors.As()` for error comparison instead of `==` to correctly handle wrapped errors.

### GO-007: No `panic` in library code
Libraries should return errors, not panic. `panic` is acceptable only in `main()` or truly unrecoverable situations.

### GO-008: Use `t.Helper()` in test helpers
Test helper functions should call `t.Helper()` so failure messages report the correct line number.

### GO-009: Group imports in standard order
Imports should be grouped: stdlib, then a blank line, then third-party, then a blank line, then internal packages.

### GO-010: Exported types should have doc comments
All exported types, functions, and package declarations should have a `//` doc comment starting with the identifier name.
