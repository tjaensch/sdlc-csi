# Swift Ruleset — Swift / iOS / macOS Best Practices

Activate by adding `swift` to the `rulesets` list in `.csi.yml`.

## Rules

### SW-001: Run SwiftLint in CI
CI pipelines should run `swiftlint` with a committed `.swiftlint.yml` configuration.

### SW-002: Use `let` over `var` where possible
Prefer immutable `let` bindings. Only use `var` when mutation is genuinely required.

### SW-003: No force unwrapping (`!`) in production code
Avoid `!` on optionals. Use `guard let`, `if let`, `??` (nil coalescing), or optional chaining instead.

### SW-004: Use `guard` for early exits
Prefer `guard let`/`guard` statements over nested `if let` for precondition checks to keep the happy path un-indented.

### SW-005: Use `Codable` for JSON serialization
Prefer `Codable` conformance over manual `JSONSerialization` for type-safe, maintainable serialization/deserialization.

### SW-006: Use Swift Package Manager for dependencies
Prefer SPM (`Package.swift`) over CocoaPods or Carthage for new projects. If `Podfile.lock` exists, it must be committed.

### SW-007: Access control should be explicit
Types and members should use the most restrictive access level possible (`private`, `fileprivate`, `internal`) rather than defaulting to `internal` everywhere.

### SW-008: No `print()` in production code
Use `os_log`, `Logger`, or a logging framework instead of `print()` for diagnostic output in apps and libraries.

### SW-009: Avoid massive view controllers
View controllers over ~200 lines should be decomposed. Extract logic into view models, coordinators, or child controllers.

### SW-010: `.build/` and `.swiftpm/` should be gitignored
SPM build artifacts and workspace state should appear in `.gitignore`.
