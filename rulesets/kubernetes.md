# Kubernetes Ruleset — Kubernetes & Helm Best Practices

Activate by adding `kubernetes` to the `rulesets` list in `.csi.yml`.

## Rules

### K8S-001: Set resource requests and limits on all containers
Every container spec should define `resources.requests` and `resources.limits` for CPU and memory. Missing limits can cause noisy-neighbor issues and OOM kills.

### K8S-002: Use liveness and readiness probes
Deployments and StatefulSets should define `livenessProbe` and `readinessProbe` on all containers. Without probes, Kubernetes cannot detect unhealthy pods.

### K8S-003: Pin container image tags — never use `latest`
Image references should use a specific tag or SHA digest (e.g., `nginx:1.25.3` or `nginx@sha256:...`). The `latest` tag causes unpredictable deployments.

### K8S-004: Run containers as non-root
Set `securityContext.runAsNonRoot: true` and `securityContext.allowPrivilegeEscalation: false` on containers. Avoid running as UID 0 unless absolutely necessary.

### K8S-005: Drop all capabilities and add only what is needed
Container security contexts should include `capabilities.drop: ["ALL"]` and explicitly add back only required capabilities.

### K8S-006: Set `imagePullPolicy` explicitly
Containers should set `imagePullPolicy` to `Always`, `IfNotPresent`, or `Never` explicitly rather than relying on the default behavior which varies by tag.

### K8S-007: Use namespaces — do not deploy to `default`
All resources should specify a `namespace`. Do not deploy workloads into the `default` namespace.

### K8S-008: Define `PodDisruptionBudget` for production workloads
Production Deployments and StatefulSets should have an associated `PodDisruptionBudget` to ensure availability during node drains and cluster upgrades.

### K8S-009: Use labels consistently
All resources should have standard labels: `app.kubernetes.io/name`, `app.kubernetes.io/version`, and `app.kubernetes.io/managed-by`. These enable consistent querying and tooling.

### K8S-010: Secrets should not be stored in plain YAML
Kubernetes Secret values should not be committed as plain base64 in manifests. Use sealed-secrets, SOPS, external-secrets, or a secret manager integration instead.
