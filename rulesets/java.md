# Java Ruleset — Java Best Practices

Activate by adding `java` to the `rulesets` list in `.csi.yml`.

## Rules

### JV-001: Use `final` for fields that never change
Class fields assigned once (in constructor or declaration) should be marked `final` to communicate intent and prevent accidental mutation.

### JV-002: No wildcard imports
Avoid `import java.util.*` — use explicit imports so dependencies are visible and IDE auto-cleanup works correctly.

### JV-003: Use SLF4J/Logback over `System.out.println`
Production code should use a logging framework (`SLF4J`, `Log4j2`, `Logback`) instead of `System.out.println` or `System.err.println`.

### JV-004: Close resources with try-with-resources
`InputStream`, `Connection`, `ResultSet`, and other `AutoCloseable` types should be managed with try-with-resources, not manual `finally` blocks.

### JV-005: No empty catch blocks
Catch blocks must at minimum log the exception. Never silently swallow exceptions with an empty `catch (Exception e) {}`.

### JV-006: Prefer `Optional` over returning `null`
Public methods should return `Optional<T>` instead of nullable references to make absence explicit at the type level.

### JV-007: Maven/Gradle wrapper should be committed
`mvnw`/`gradlew` wrapper scripts and their `.mvn/` or `gradle/` directories should be committed so builds are reproducible without requiring a pre-installed build tool.

### JV-008: `target/` and `build/` must be gitignored
Build output directories must appear in `.gitignore`.

### JV-009: Pin dependency versions
`pom.xml` `<dependency>` entries should specify explicit versions. Avoid `LATEST` or `RELEASE` version ranges. In Gradle, avoid `+` dynamic versions.

### JV-010: Use Java version property consistently
Multi-module Maven projects should define `<maven.compiler.source>` and `<maven.compiler.target>` (or `<java.version>` in Spring Boot) in the parent POM, not repeated in each module.
