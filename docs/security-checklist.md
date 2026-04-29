# Security Checklist for New Deployments

What every new deployment in this cluster needs to satisfy before merging. Use this as a pre-merge review checklist.

## TL;DR — minimum required

For any new app being deployed:

1. **`securityContext`** on pod and containers (see [Pod Security Standards](#pod-security-standards))
2. **`resources.requests` and `resources.limits`** on every container
3. **`readinessProbe` and `livenessProbe`** on every container
4. **Image pinned to a tag** (no `:latest`), pulled from `harbor.theedgeworks.ai/...` when possible
5. **Namespace `networkpolicy.yaml`** following Pattern A (or B/C if applicable)
6. **Namespace labeled with PSS enforce level** (`restricted` preferred, `baseline` if upstream image runs as root)

If your app violates any of these, document the reason inline as a comment and link to the audit memo or memory entry.

---

## Pod Security Standards

The cluster enforces Pod Security Standards via namespace labels. Two levels are in active use:

| Level | When to use | Required fields |
|---|---|---|
| **`restricted`** | Default for new apps. Image runs as a non-root user. | All fields below, including `runAsNonRoot: true` |
| **`baseline`** | Image runs as root and can't be migrated cleanly (e.g., upstream lacks `USER` directive and PVC permissions block migration). Documented exception. | All fields below EXCEPT `runAsNonRoot` |

### Required `securityContext` template

**Pod-level** (`spec.template.spec.securityContext`):
```yaml
securityContext:
  runAsNonRoot: true                   # OMIT if running as root (baseline only)
  runAsUser: 1000                      # The image's expected non-root UID
  runAsGroup: 1000
  fsGroup: 1000                        # Required if a PVC is mounted
  seccompProfile:
    type: RuntimeDefault
```

**Container-level** (`spec.template.spec.containers[*].securityContext`):
```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true         # PREFER true; set false only if app needs to write
```

### Choosing between `restricted` and `baseline`

Run this on a candidate image to find its default user:
```bash
docker run --rm --entrypoint id <image>:<tag>
```

- Returns `uid=0(root)` → check upstream Dockerfile for `USER` directive. If absent and you can't override at runtime cleanly → `baseline` with documented reason
- Returns `uid=N(...)` where N != 0 → use `restricted`

### Namespace labels

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted    # or baseline
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
```

Always keep `warn` and `audit` at `restricted` even when `enforce` is at `baseline` — surfaces drift if a future change makes the workload restricted-compliant.

---

## NetworkPolicy

Every namespace with workloads should have a `networkpolicy.yaml` following one of three patterns.

### Pattern A — internal app (most common)

For apps where pods talk only to other pods in the same namespace, plus accept public traffic via ingress-nginx and allow Prometheus to scrape:

Four policies in a single file:
- `default-deny-ingress` — empty guest list (the bouncer)
- `allow-same-namespace` — pods in this namespace can reach each other
- `allow-monitoring` — `monitoring` namespace can scrape any pod
- `allow-ingress-nginx` — ingress controller can reach the app pod on its service port

Use the existing `apps/devpi/networkpolicy.yaml` or `apps/chromadb/networkpolicy.yaml` as templates.

### Pattern B — monitoring/observability

Pattern A **plus** an `allow-otlp-from-cluster` rule that lets every namespace push telemetry to the OTel collector. See `apps/kube-prometheus-stack/networkpolicy.yaml`.

### Pattern C — egress-only worker

For pods that initiate outbound connections only and accept no inbound (e.g., ARC runners polling GitHub, cloudflared tunnel):

Just one policy:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: <ns>
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

### Cross-namespace allow rules

Only add cross-namespace ingress allows when traffic actually flows between namespaces via cluster DNS (`svc.cluster.local`). Most apps that look cross-cluster (e.g., OIDC redirects to Keycloak) actually exit via the public hostname and re-enter through `ingress-nginx` — that's already covered by `allow-ingress-nginx`.

If unsure, check the app's config: if it points at `https://auth.theedgeworks.ai` (or similar public hostname), no cross-ns allow is needed.

---

## Resource limits

Every container must declare both:

```yaml
resources:
  requests:
    cpu: 100m            # or higher; this reserves capacity
    memory: 128Mi
  limits:
    cpu: 500m            # cap to prevent runaway
    memory: 512Mi
```

Why both:
- **Requests** = scheduler reservation. Without it, K8s thinks the pod uses 0 and may overcommit a node.
- **Limits** = cgroup ceiling. Without it, a noisy pod can OOM the node and evict everything else.

---

## Probes

Every long-running container needs:

```yaml
readinessProbe:
  httpGet:
    path: /healthz       # or whatever the app exposes
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
livenessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 30
  periodSeconds: 30
```

If the app has no health endpoint, a TCP probe on the listen port is the minimum acceptable fallback.

---

## Image hygiene

| Rule | Why |
|---|---|
| Pull from `harbor.theedgeworks.ai/<project>/<image>:<tag>` for internal apps | Trivy scans, replication, audit |
| Pull from `quay.io`, `ghcr.io`, `registry.k8s.io` for upstream | Avoid Docker Hub rate limits |
| **Never use `:latest`** | Mutable tag = supply-chain footgun |
| Use specific version tags: `:v1.2.3` not `:1` | Reproducibility |
| Pin by digest where possible: `image@sha256:...` | Strongest immutability guarantee |
| `imagePullPolicy: Always` only if you intentionally repush the same tag | Otherwise `IfNotPresent` is fine |

If using a private Harbor image, add `imagePullSecrets` to the deployment.

---

## Secrets

- **Never** put secret values directly in env: `value: "mypassword"`
- **Always** use `valueFrom.secretKeyRef`:
  ```yaml
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-app-secret
        key: password
  ```
- **Never** commit secret manifests with values to git. Use sealed-secrets, External Secrets Operator, or pre-create the secret manually with `kubectl create secret`.

---

## Pre-merge checklist

Before opening a PR for a new deployment:

- [ ] `securityContext` set at pod and container level (see template above)
- [ ] PSS enforce label on namespace (`restricted` or documented `baseline`)
- [ ] `networkpolicy.yaml` present (Pattern A/B/C as appropriate)
- [ ] `resources.requests` and `resources.limits` on every container
- [ ] `readinessProbe` and `livenessProbe` on every container
- [ ] Image tag pinned (no `:latest`)
- [ ] No secret values in env (`secretKeyRef` only)
- [ ] If from a Helm chart, verify chart's defaults satisfy the above (override values if not)
- [ ] If a documented exception (e.g., chromadb runs as root), inline comment explaining why

## Existing exceptions (don't replicate)

| Workload | Why exempt | Documented in |
|---|---|---|
| `chromadb` | Upstream image lacks `USER` directive; existing PVC SQLite file mode 0644 blocks non-root migration | inline comment in `apps/chromadb/namespace.yaml` |
| `kube-prometheus-stack-prometheus-node-exporter` | Needs `hostNetwork`, `hostPID`, `hostPath:/proc` to scrape host-level metrics | namespace stays at PSS warn-only or per-pod exemption when monitoring promotes to baseline |
| `opentelemetry-collector-agent` | DaemonSet reads pod logs from `/var/log/pods` (`hostPath`) | same as above |
| `longhorn-system` | Storage I/O needs privileged + host root mount | namespace labeled `enforce=privileged`, intentional |
| `metallb-system` | Speaker uses `hostNetwork` for L2 ARP advertisement | namespace labeled `enforce=privileged`, intentional |

If you're considering a new exception, check whether a runtime-only override (`runAsUser`, `fsGroup`, etc.) avoids needing one. Most "image runs as root" cases can be solved with `runAsUser: <expected-uid>` + `fsGroup: <expected-gid>` if the image doesn't validate UID at startup.

---

## Reference deployment (annotated)

Minimal compliant deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      securityContext:                          # POD-LEVEL
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: my-app
          image: harbor.theedgeworks.ai/myorg/my-app:v1.0.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
              name: http
          securityContext:                      # CONTAINER-LEVEL
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 15
            periodSeconds: 30
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: my-app-secret
                  key: password
```

---

## When something doesn't fit

If a new app legitimately can't satisfy the checklist (e.g., CSI driver needs hostPath, cluster-internal proxy needs `NET_ADMIN`), the right path is:

1. Document the violation inline as a comment with a brief reason
2. Lower the namespace's `enforce` label one notch (`restricted` → `baseline`, or `baseline` → `privileged`)
3. Keep `warn` and `audit` at `restricted` so future maintainers see the gap
4. Add a row to the [exceptions table](#existing-exceptions-dont-replicate) above

Don't silently skip the checklist; an inline comment + audit-trail label makes the trade-off visible.
