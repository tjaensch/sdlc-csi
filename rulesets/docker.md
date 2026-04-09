# Docker Ruleset — Dockerfile & Compose Best Practices

Activate by adding `docker` to the `rulesets` list in `.csi.yml`.

## Rules

### DK-001: Pin base image tags
`FROM` instructions should use specific version tags (e.g., `node:20-alpine`), never `:latest` or untagged images.

### DK-002: Use multi-stage builds
Production images should use multi-stage builds to separate build dependencies from the runtime image, reducing size and attack surface.

### DK-003: Don't run as root
Dockerfiles should include a `USER` instruction to run the application as a non-root user. Avoid `USER root` in the final stage.

### DK-004: Use `.dockerignore`
A `.dockerignore` file should exist to exclude `.git/`, `node_modules/`, `.env`, build artifacts, and other unnecessary files from the build context.

### DK-005: No secrets in Dockerfile
Never use `ENV`, `ARG`, or `COPY` to embed secrets (API keys, passwords, tokens) in images. Use build-time secrets (`--mount=type=secret`) or runtime injection.

### DK-006: Order layers for cache efficiency
Place frequently changing instructions (`COPY . .`, `RUN build`) after stable ones (`FROM`, `RUN apt-get`, `COPY package.json`). Copy dependency manifests before source code.

### DK-007: Use `HEALTHCHECK` for production images
Production Dockerfiles should include a `HEALTHCHECK` instruction so orchestrators can detect unhealthy containers.

### DK-008: Minimize image layers
Combine related `RUN` commands with `&&` and clean up in the same layer (e.g., `apt-get install && rm -rf /var/lib/apt/lists/*`).

### DK-009: Use `COPY` over `ADD`
Prefer `COPY` for copying local files. Only use `ADD` when you need tar auto-extraction or remote URL fetching (which is itself discouraged).

### DK-010: Pin versions in `apt-get` / `apk` installs
Package installs should pin versions where possible (e.g., `curl=7.88.1-10`) or at minimum use `--no-install-recommends` to reduce image bloat.
