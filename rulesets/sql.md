# SQL Ruleset — SQL-Specific Best Practices

Activate by adding `sql` to the `rulesets` list in `.csi.yml`.

## Rules

### SQL-001: No `SELECT *` in production queries
Production queries and views should explicitly list columns instead of using `SELECT *`. This prevents breakage when upstream schemas change and improves readability.

### SQL-002: Use explicit `JOIN` syntax
Always use explicit `JOIN ... ON` syntax instead of implicit comma joins with `WHERE` conditions. This makes join logic clear and separable from filter logic.

### SQL-003: Prefer CTEs over deeply nested subqueries
Common Table Expressions (`WITH` clauses) should be used instead of subqueries nested more than one level deep. CTEs improve readability or allow reuse of intermediate results.

### SQL-004: Use consistent naming conventions
Table and column names should use `snake_case`. Avoid mixed case, camelCase, or spaces. Aliases should be meaningful — avoid single-letter aliases like `a`, `b`, `c` except in trivial cases.

### SQL-005: No hardcoded dates, IDs, or magic numbers
Queries should not contain hardcoded filter values like `WHERE id = 42` or `WHERE date > '2024-01-01'`. Use parameters, variables, or configuration tables instead.

### SQL-006: Qualify column names in multi-table queries
When a query involves more than one table, all column references should be table-qualified (e.g., `orders.customer_id`) to avoid ambiguity and breakage when schemas change.

### SQL-007: Use `COALESCE` or `IFNULL` to handle NULLs explicitly
Columns that may contain NULL values should be handled explicitly with `COALESCE`, `IFNULL`, or `CASE` expressions rather than relying on implicit NULL behavior in comparisons and aggregations.

### SQL-008: Avoid `ORDER BY` column position
Use column names or aliases in `ORDER BY` clauses instead of ordinal positions (e.g., `ORDER BY 1, 2`). Positional references break silently when the select list changes.

### SQL-009: Use `UNION ALL` instead of `UNION` unless deduplication is required
`UNION` performs an implicit `DISTINCT` which adds sorting overhead. Use `UNION ALL` when duplicate elimination is not needed.

### SQL-010: SQL keywords should use consistent casing
SQL keywords (`SELECT`, `FROM`, `WHERE`, `JOIN`, etc.) should use a consistent casing style — either all uppercase or all lowercase — throughout the project.
