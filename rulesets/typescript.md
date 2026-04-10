# TypeScript Ruleset — TypeScript-Specific Best Practices

Activate by adding `typescript` to the `rulesets` list in `.csi.yml`.

## Rules

### TS-001: Enable `strict` mode in `tsconfig.json`
The `tsconfig.json` should have `"strict": true` or at minimum enable `strictNullChecks` and `noImplicitAny`. Loose configs hide type errors.

### TS-002: Avoid `any` type
Do not use `any` as a type annotation. Use `unknown` when the type is truly unknown, or define a proper type/interface. Suppress only with `// eslint-disable` and a justification comment.

### TS-003: Prefer `interface` for object shapes, `type` for unions and intersections
Use `interface` for object shapes that may be extended. Use `type` for unions, intersections, mapped types, and utility types. Be consistent within the project.

### TS-004: Use `readonly` for immutable data
Properties, arrays, and parameters that should not be mutated should be marked `readonly` or use `ReadonlyArray<T>`.

### TS-005: No non-null assertions (`!`) without justification
The non-null assertion operator (`value!`) bypasses type safety. Prefer proper null checks, optional chaining (`?.`), or narrowing. If unavoidable, add a comment explaining why.

### TS-006: Avoid `enum` — prefer `as const` objects or union types
TypeScript enums have runtime quirks and emit unexpected JavaScript. Prefer `as const` objects or string literal union types for most use cases.

### TS-007: Exported functions and public methods should have explicit return types
Exported functions and public class methods should declare return types explicitly rather than relying on inference. This prevents accidental API changes.

### TS-008: No `@ts-ignore` without explanation
`@ts-ignore` silences all errors on the next line. Prefer `@ts-expect-error` with a description. If `@ts-ignore` is unavoidable, add a comment explaining the reason.

### TS-009: Use path aliases over deep relative imports
Projects with deep directory structures should configure `paths` in `tsconfig.json` (e.g., `@/utils`) instead of fragile relative imports like `../../../utils`.

### TS-010: Keep `tsconfig.json` and dependency types in sync
Type packages (`@types/*`) should match the version of the corresponding library. Unused `@types/*` packages should be removed.
