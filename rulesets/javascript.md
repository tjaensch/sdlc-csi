# JavaScript Ruleset — JavaScript Best Practices

Activate by adding `javascript` to the `rulesets` list in `.csi.yml`.
For TypeScript-specific rules, also add the `typescript` ruleset.

## Rules

### JS-001: `package-lock.json` or `yarn.lock` must be committed
Lockfiles ensure reproducible installs. If `package.json` exists, a lockfile should be committed alongside it.

### JS-002: No `console.log` in production code
Use a structured logging library (e.g., `winston`, `pino`) instead of `console.log` in server/library code. `console.log` is acceptable in scripts and development tools.

### JS-003: ESLint or Biome config should exist
Projects should have a linter configuration file (`.eslintrc.*`, `eslint.config.*`, or `biome.json`). If present, it should be enforced in CI.

### JS-004: Pin Node.js version
Use an `.nvmrc`, `.node-version`, or `engines` field in `package.json` to declare the required Node.js version. This prevents "works on my machine" issues across environments.

### JS-005: No deprecated packages
Replace known deprecated packages: `request` → `got`/`axios`, `moment` → `dayjs`/`date-fns`, `tslint` → `eslint`, `colors` → `chalk`/`picocolors`.

### JS-006: `node_modules` must be gitignored
The `node_modules/` directory must appear in `.gitignore`.

### JS-007: Scripts in `package.json` should exist
Scripts referenced in `package.json` `"scripts"` should point to files or commands that exist.

### JS-008: Use `===` and `!==` over `==` and `!=`
Always use strict equality (`===` / `!==`) to avoid JavaScript's implicit type coercion rules, which cause subtle bugs (e.g., `0 == ""` is `true`).

### JS-009: Use `const` and `let` over `var`
Modern code should use `const` (preferred) or `let` instead of `var`.

### JS-010: Environment variables should have fallbacks or validation
`process.env.VARIABLE` usage should include validation or fallback defaults, not raw access that could be `undefined`.
