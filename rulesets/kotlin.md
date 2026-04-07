# Kotlin Ruleset — Kotlin Best Practices

Activate by adding `kotlin` to the `rulesets` list in `.csi.yml`.

## Rules

### KT-001: Use `val` over `var` where possible
Prefer immutable `val` declarations. Only use `var` when reassignment is genuinely needed.

### KT-002: Use data classes for DTOs
Plain data holders should be `data class` to get `equals()`, `hashCode()`, `toString()`, and `copy()` for free.

### KT-003: No forced non-null assertions (`!!`) in production code
Avoid `!!` — use safe calls (`?.`), `let`, `require()`, or `checkNotNull()` with descriptive messages instead.

### KT-004: Use `require` / `check` for preconditions
Validate function arguments with `require()` and state with `check()` instead of manual `if/throw` blocks.

### KT-005: Run `ktlint` or `detekt` in CI
CI pipelines should enforce code style via `ktlint` or run static analysis via `detekt` with a committed config.

### KT-006: Use coroutines over raw threads
Prefer Kotlin coroutines (`suspend` functions, `CoroutineScope`) over `Thread`, `Executor`, or `AsyncTask` for concurrency.

### KT-007: Avoid `companion object` for constants
Top-level `const val` is preferred over `companion object { const val }` for simple constants — it avoids an extra class.

### KT-008: Use sealed classes/interfaces for restricted hierarchies
State machines, result types, and API responses should use `sealed class` or `sealed interface` instead of enums with data or open class hierarchies.

### KT-009: Gradle build files should use Kotlin DSL
Prefer `build.gradle.kts` over `build.gradle` for type-safe build configuration with IDE autocompletion.

### KT-010: No `lateinit` for nullable types
`lateinit` should only be used when initialization is guaranteed before access (e.g., DI injection). For optional values, use nullable types with `?`.
