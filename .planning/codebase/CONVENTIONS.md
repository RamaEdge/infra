# Coding Conventions

**Analysis Date:** 2026-02-28

## Overview

This codebase is a Kubernetes/Flux GitOps infrastructure-as-code repository. All code is YAML configuration manifests for Kubernetes resources, Helm releases, and Flux/Kustomize definitions. There is no application code (JavaScript, TypeScript, Python, etc.). Conventions apply to YAML structure, metadata, and documentation practices.

## Naming Patterns

**Files:**
- Kubernetes resource files: `{type}-lowercase-with-hyphens.yaml` (e.g., `helmrelease.yaml`, `namespace.yaml`, `postgres-helmrelease.yaml`)
- Kustomization files: Always named `kustomization.yaml`
- HelmRepository files: Named `{chartname}-helmrepository.yaml` (e.g., `minio-helmrepository.yaml`, `harbor-helmrepository.yaml`)
- Ingress files: Named `ingress.yaml` or `{service}-{purpose}-ingress.yaml` (e.g., `minio-console-ingress.yaml`)
- Component-specific dashboards: `dashboard-{component}.yaml` (e.g., `dashboard-harbor.yaml`, `dashboard-nginx-ingress.yaml`)
- Monitoring resources: `servicemonitor-{component}.yaml` (e.g., `servicemonitor-harbor.yaml`)

**Kubernetes Metadata Names:**
- Resource names: lowercase with hyphens (e.g., `minio-console-ingress`, `harbor-exporter`, `redis-service`)
- Namespace names: lowercase with hyphens (e.g., `actions-runner-system`, `minio-tenant`, `monitoring`)
- Labels: lowercase with hyphens (e.g., `app: harbor`, `component: registry`, `app.kubernetes.io/name: loki`)
- Annotation keys: lowercase with forward slashes for domains (e.g., `nginx.ingress.kubernetes.io/ssl-redirect`, `helm.toolkit.fluxcd.io/driftDetection`)

**Directory Structure:**
- Cluster configuration: `clusters/k3s-cluster/`
- Flux system resources: `flux-system/`
- Applications: `apps/{app-name}/`
- Monitoring configuration: `apps/monitoring-config/`

## Code Style

**YAML Formatting:**
- Indentation: 2 spaces (standard Kubernetes YAML)
- Line length: No hard limit but keep reasonable for readability
- Field order: Follow Kubernetes API convention - metadata before spec
- Multiline strings: Use `|` for preserved newlines (script content), `>` for folded text

**Metadata Section:**
```yaml
metadata:
  name: {lowercase-name}
  namespace: {namespace-name}
  labels:              # Optional, used for grouping
    {key}: {value}
  annotations:         # Optional, metadata for tools/controllers
    {key}: {value}
```

**Spec Section:**
- Most important/highest-level fields first
- Logical grouping by feature/concern
- Comments above field groups explaining purpose

## Comments

**When to Comment:**
- Complex or non-obvious configurations require explanation
- Security-relevant settings (TLS, auth, RBAC)
- Resource constraints and their reasoning
- Known limitations or workarounds
- Integration points between resources

**Comment Format:**
- Inline comments for specific fields: `field: value  # Explanation`
- Section comments (block separators): `# Description of section below`
- Multi-line explanations: Start with `# ` on each line
- Document-level header (first 5-10 lines): Explain purpose and key details

**Example from codebase:**
```yaml
# Harbor Metrics Configuration
#
# Harbor has a dedicated exporter component that collects metrics from all Harbor
# components. This is the primary source of harbor_* metrics (artifact counts,
# project quotas, etc.).
#
# The registry component also exposes its own registry_* metrics on port 8001
# (HTTP request durations, in-flight requests, etc.).
```

## Configuration Organization

**HelmRelease Structure Pattern (`clusters/k3s-cluster/apps/{app}/helmrelease.yaml`):**
1. apiVersion and kind (Flux HelmRelease)
2. metadata (name, namespace)
3. spec with:
   - interval: Reconciliation frequency
   - targetNamespace: Where to deploy
   - dependsOn: Other resources this depends on (e.g., databases first)
   - install/upgrade sections (remediation, retries)
   - chart specification (chart name, version, sourceRef)
   - values: Helm chart values (configuration specific to the application)

**Values Organization within HelmRelease:**
- Image configuration first (repository, tag)
- Service/networking configuration
- Persistence configuration
- Security contexts
- Resource requests/limits
- Monitoring/metrics configuration
- Disable unnecessary components (chartmuseum, notary, etc.)

## Import/Dependency Organization

**Kustomization Files:**
- Simple list of resources in reading order
- Dependencies explicit: `namespace.yaml` typically first
- Comments above complex resource lists explaining dependencies

**Example (`clusters/k3s-cluster/apps/keycloak/kustomization.yaml`):**
```yaml
resources:
  - namespace.yaml
  - postgres-helmrelease.yaml    # Database first
  - helmrelease.yaml             # App depends on database
```

**Flux Dependency Declaration:**
```yaml
spec:
  dependsOn:
    - name: keycloak-db
      namespace: flux-system
```

## Error Handling / Resource Management

**Installation Remediation:**
```yaml
install:
  createNamespace: false
  remediation:
    retries: 3
```

**CRD Handling:**
```yaml
install:
  crds: CreateReplace    # Or Skip if not needed
upgrade:
  crds: CreateReplace
```

**Resource Limits (Always Specified):**
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

Pattern: Always set both requests and limits. Requests are used for scheduling, limits prevent resource hogging.

## Storage Configuration Convention

**PersistentVolumeClaim Pattern:**
```yaml
persistence:
  enabled: true
  persistentVolumeClaim:
    {component}:
      size: {capacity}
      accessMode: ReadWriteOnce        # Or ReadWriteMany for RWX
      storageClass: longhorn            # Use longhorn for persistent storage
```

**Mount Path Convention:**
- Follow upstream Helm chart conventions
- Document in comments if non-standard (e.g., registry uses `/var/lib/registry`)

## Networking Conventions

**Ingress Configuration:**
```yaml
expose:
  type: ingress
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: {app}-tls
  ingress:
    hosts:
      core: {hostname}
    className: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-body-size: "0"
```

**Service Naming:**
- Cross-namespace communication: `{service-name}.{namespace}.svc.cluster.local`
- Example: `redis-service.harbor.svc.cluster.local:6379`

**Port Naming:**
- Standard ports: `8080` (HTTP), `8443` (HTTPS), `9090` (Prometheus metrics)
- Component-specific ports documented in comments

## Security Contexts

**Pattern Used:**
```yaml
securityContext:
  runAsUser: 10000           # Non-root user
  runAsGroup: 10000
  fsGroup: 10000             # File ownership
  fsGroupChangePolicy: OnRootMismatch
```

Always run as non-root except where unavoidable. Document UID selection rationale in comments.

## Monitoring and Metrics

**ServiceMonitor/PodMonitor Pattern:**
```yaml
podMetricsEndpoints:
  - targetPort: 8001
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
```

**Labels for Prometheus Operator:**
```yaml
labels:
  app: kube-prometheus-stack
  release: kube-prometheus-stack
```

## Special Cases & Workarounds

**Commented-Out Resources:**
- Use `#` to disable resources (e.g., minio-tenant-ks.yaml in flux-system/kustomization.yaml)
- Add comment explaining why: `# apps/minio is deployed via flux-system/minio-tenant-ks.yaml`

**Deprecated Fields:**
- Keep documentation of why they're used (e.g., ARM64 compatibility overrides)

**Known Limitations:**
- Document in inline comments (e.g., "Command override not supported by Harbor Helm chart")

---

*Convention analysis: 2026-02-28*
