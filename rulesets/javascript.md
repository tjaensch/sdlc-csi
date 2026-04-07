# JavaScript / TypeScript Ruleset — JS/TS Best Practices

Activate by adding `javascript` to the `rulesets` list in `.csi.yml`.

## Rules

### JS-001: `package-lock.json` or `yarn.lock` must be committed
Lockfiles ensure reproducible installs. If `package.json` exists, a lockfile should be committed alongside it.

### JS-002: No `console.log` in production code
Use a structured logging library (e.g., `winston`, `pino`) instead of `console.log` in server/library code. `console.log` is acceptable in scripts and development tools.

### JS-003: ESLint or Biome config should exist
Projects should have a linter configuration file (`.eslintrc.*`, `eslint.config.*`, or `biome.json`). If present, it should be enforced in CI.

### JS-004: TypeScript strict mode recommended
`tsconfig.json` should enable `"strict": true` or at minimum `"strictNullChecks": true` and `"noImplicitAny": true`.

### JS-005: No deprecated packages
Replace known deprecated packages: `request` → `got`/`axios`, `moment` → `dayjs`/`date-fns`, `tslint` → `eslint`, `colors` → `chalk`/`picocolors`.

### JS-006: `node_modules` must be gitignored
The `node_modules/` directory must appear in `.gitignore`.

### JS-007: Scripts in `package.json` should exist
Scripts referenced in `package.json` `"scripts"` should point to files or commands that exist.

### JS-008: No `any` type in TypeScript (prefer `unknown`)
Avoid `any` type annotations. Use `unknown` with type narrowing, or define proper interfaces/types.

### JS-009: Use `const` and `let` over `var`
Modern code should use `const` (preferred) or `let` instead of `var`.

### JS-010: Environment variables should have fallbacks or validation
`process.env.VARIABLE` usage should include validation or fallback defaults, not raw access that could be `undefined`.
