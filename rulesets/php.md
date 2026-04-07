# PHP Ruleset — PHP Best Practices

Activate by adding `php` to the `rulesets` list in `.csi.yml`.

## Rules

### PHP-001: Use strict types
All PHP files should declare `declare(strict_types=1);` at the top to enforce type safety.

### PHP-002: `composer.lock` must be committed for applications
Applications should commit `composer.lock` for reproducible installs. Libraries may omit it.

### PHP-003: Run PHPStan or Psalm in CI
CI pipelines should run static analysis at level 5+ via PHPStan or Psalm with a committed config.

### PHP-004: Use type declarations on all function signatures
All functions and methods should have parameter types and return type declarations. Avoid `mixed` unless genuinely needed.

### PHP-005: No `@` error suppression operator
The `@` operator hides errors. Handle errors explicitly with try/catch or conditional checks.

### PHP-006: No `eval()` or dynamic `include` with user input
Never use `eval()`. Dynamic `include`/`require` must never incorporate unsanitized user input (code injection risk).

### PHP-007: Use PDO with prepared statements for database access
Avoid raw `mysql_*` or `mysqli_*` with string concatenation. Use PDO or an ORM with parameterized queries to prevent SQL injection.

### PHP-008: `vendor/` must be gitignored
The `vendor/` Composer directory must appear in `.gitignore`.

### PHP-009: Use PSR-4 autoloading
Projects should use PSR-4 autoloading via `composer.json` instead of manual `require` chains.

### PHP-010: No `var_dump` / `print_r` / `error_log` in production
Use a PSR-3 logger (Monolog, etc.) instead of debug output functions in production code.
