# Ruby Ruleset — Ruby Best Practices

Activate by adding `ruby` to the `rulesets` list in `.csi.yml`.

## Rules

### RB-001: Run RuboCop in CI
CI pipelines should run `rubocop` with a committed `.rubocop.yml` configuration.

### RB-002: `Gemfile.lock` must be committed for applications
Applications should commit `Gemfile.lock` for reproducible installs. Gems/libraries may omit it.

### RB-003: Use `frozen_string_literal: true`
Ruby files should include the `# frozen_string_literal: true` magic comment to prevent accidental string mutation and improve performance.

### RB-004: No `rescue Exception`
Rescue specific exception classes. `rescue Exception` catches `SignalException` and `SystemExit`, which is almost never intended.

### RB-005: Prefer `fetch` with default over `[]` for hashes
Use `hash.fetch(:key, default)` or `hash.fetch(:key) { compute }` instead of `hash[:key] || default` to handle `nil` and `false` values correctly.

### RB-006: Use `require_relative` for local files
Prefer `require_relative` over `require` with path manipulation for loading files within the same project.

### RB-007: No `puts` or `p` in production code
Use `Rails.logger` or `Logger` instead of `puts`/`p`/`pp` for diagnostic output in applications and libraries.

### RB-008: Database migrations should be reversible
ActiveRecord migrations should define both `up` and `down` (or use `change` with reversible methods) so rollbacks work.

### RB-009: Pin Ruby version
A `.ruby-version` file or `ruby` declaration in `Gemfile` should specify the project's Ruby version.

### RB-010: Avoid monkey-patching core classes
Do not reopen `String`, `Array`, `Hash`, or other core classes unless absolutely necessary and well-documented.
