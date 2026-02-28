# Phase 3: Replicated Storage - Research

**Researched:** 2026-02-28
**Domain:** Longhorn StorageClass configuration, Kubernetes GitOps (Flux CD), Helm persistence values
**Confidence:** HIGH

## Summary

Phase 3 creates a `longhorn-replicated` StorageClass with `numberOfReplicas: "2"` and updates six specific PVCs across four applications (Forgejo app data, Forgejo PostgreSQL, Keycloak PostgreSQL, Harbor internal database, and Smedja PostgreSQL) to use it. The default `longhorn` StorageClass is intentionally left unchanged so non-critical workloads are unaffected.

The work is pure GitOps: a new raw Kubernetes manifest for the StorageClass is added to the repo, and six HelmRelease `values.persistence.storageClass` fields are changed from `longhorn` to `longhorn-replicated`. No new Helm repositories, operators, or controllers are required — Longhorn's CSI driver (`driver.longhorn.io`) already handles all provisioning. These are new deployments with no data migration required.

**Smedja is not yet deployed** in this repository. STOR-06 requires a PostgreSQL PVC with `longhorn-replicated`, which means a Smedja application directory must be created alongside the other changes, or the requirement scoped to a placeholder. This is the only ambiguity requiring a decision during planning.

**Primary recommendation:** Create one new `StorageClass` manifest, update five existing HelmRelease files (Forgejo app, Forgejo postgres, Keycloak postgres, Harbor app), and create a new Smedja postgres placeholder. Keep the default `longhorn` StorageClass unchanged by NOT annotating `longhorn-replicated` as default.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| STOR-01 | `longhorn-replicated` StorageClass defined with replica count 2+ | StorageClass manifest with `numberOfReplicas: "2"`, provisioner `driver.longhorn.io` — see Code Examples |
| STOR-02 | Forgejo app data PVC (200Gi) uses longhorn-replicated | Change `persistence.storageClass: longhorn` → `longhorn-replicated` in `apps/forgejo/helmrelease.yaml` |
| STOR-03 | Forgejo PostgreSQL PVC (1Gi) uses longhorn-replicated | Change `primary.persistence.storageClass` in `apps/forgejo/postgres-helmrelease.yaml` |
| STOR-04 | Keycloak PostgreSQL PVC (1Gi) uses longhorn-replicated | Change `primary.persistence.storageClass` in `apps/keycloak/postgres-helmrelease.yaml` |
| STOR-05 | Harbor PostgreSQL PVC (1Gi) uses longhorn-replicated | Change `persistence.persistentVolumeClaim.database.storageClass` in `apps/harbor/helmrelease.yaml` |
| STOR-06 | Smedja PostgreSQL PVC (10Gi) uses longhorn-replicated | Smedja does not exist in repo — requires new `apps/smedja/` directory with postgres HelmRelease using `longhorn-replicated` |
</phase_requirements>

## Standard Stack

### Core

| Component | Version/Kind | Purpose | Why Standard |
|-----------|-------------|---------|--------------|
| Longhorn StorageClass | `storage.k8s.io/v1` | Defines replicated volume provisioning | Longhorn is already the cluster storage provider; creating a second SC is native Kubernetes |
| Longhorn CSI Driver | `driver.longhorn.io` | Provisions PVCs against Longhorn backend | This is the fixed provisioner name for all Longhorn StorageClasses |
| Bitnami PostgreSQL Helm chart | 18.1.13 (pinned) | Deploys Forgejo/Keycloak postgres | Already used in repo for both databases; `primary.persistence.storageClass` is the correct values path |
| Flux CD HelmRelease | `helm.toolkit.fluxcd.io/v2` | Manages all Helm deployments | All app deployments already use this API |

### Supporting

| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| Raw Kubernetes StorageClass YAML | n/a | Declares `longhorn-replicated` class | StorageClass is a cluster-scoped resource; not provisioned through Helm |
| Kustomize resource list | n/a | Registers the new StorageClass with Flux | Follow existing pattern: add to a Kustomization's `resources:` list |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw StorageClass YAML in repo | Longhorn Helm chart values to add a custom SC | The Longhorn Helm chart does not easily support additional user-defined StorageClasses; raw YAML is cleaner and simpler |
| `numberOfReplicas: "2"` | `numberOfReplicas: "3"` | 3 replicas is safer but wastes storage on a 4-6 node cluster where only 1 node failure survivability is needed |
| `dataLocality: disabled` (default) | `dataLocality: best-effort` | best-effort keeps a local copy for performance but can cause issues when replica migration is needed; disabled is more predictable for fault-tolerance focus |

## Architecture Patterns

### Recommended Project Structure

```
clusters/k3s-cluster/
├── apps/
│   ├── longhorn-config/           # NEW: cluster storage config (StorageClass)
│   │   ├── kustomization.yaml
│   │   └── storageclass-replicated.yaml
│   ├── forgejo/
│   │   ├── helmrelease.yaml       # CHANGE: storageClass → longhorn-replicated
│   │   └── postgres-helmrelease.yaml  # CHANGE: storageClass → longhorn-replicated
│   ├── keycloak/
│   │   └── postgres-helmrelease.yaml  # CHANGE: storageClass → longhorn-replicated
│   ├── harbor/
│   │   └── helmrelease.yaml       # CHANGE: database.storageClass → longhorn-replicated
│   └── smedja/                    # NEW: Smedja application (STOR-06)
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       └── postgres-helmrelease.yaml  # NEW: uses longhorn-replicated
└── kustomization.yaml             # CHANGE: add apps/longhorn-config (and apps/smedja if applicable)
```

### Pattern 1: StorageClass Manifest (Cluster-Scoped Resource)

**What:** A plain Kubernetes StorageClass resource committed to the repo and included in a Flux Kustomization.
**When to use:** For cluster-scoped resources (StorageClass, ClusterRole, etc.) that don't belong inside any single application's namespace.

```yaml
# Source: https://longhorn.io/docs/1.11.0/references/storage-class-parameters/
# File: clusters/k3s-cluster/apps/longhorn-config/storageclass-replicated.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-replicated
  # Do NOT add storageclass.kubernetes.io/is-default-class: "true"
  # The existing 'longhorn' StorageClass remains the cluster default
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "30"
  fsType: "ext4"
```

**Key constraints:**
- `provisioner` MUST be `driver.longhorn.io` — this is the fixed identifier for Longhorn's CSI driver
- `numberOfReplicas` MUST be a string (quoted), not an integer
- `staleReplicaTimeout` is in minutes; 30 minutes is the default (2880 = 48h was from old docs)
- Do NOT set `storageclass.kubernetes.io/is-default-class: "true"` — this would displace the existing default

### Pattern 2: Bitnami PostgreSQL storageClass Value

**What:** The correct values key for Bitnami PostgreSQL Helm chart to specify storage class for the primary instance.
**When to use:** For Forgejo and Keycloak PostgreSQL HelmReleases (both use `bitnami/postgresql` chart 18.1.13).

```yaml
# Source: https://github.com/bitnami/charts/blob/main/bitnami/postgresql/values.yaml
values:
  primary:
    persistence:
      enabled: true
      storageClass: longhorn-replicated   # was: longhorn
      size: 1Gi
```

**Important:** The path is `primary.persistence.storageClass`, NOT `persistence.storageClass`. The Bitnami chart organizes persistence under the `primary` key for the primary StatefulSet.

### Pattern 3: Harbor Internal Database storageClass Value

**What:** Harbor's internal PostgreSQL database has a different values path because Harbor manages its own database pod.
**When to use:** For the Harbor `helmrelease.yaml` (STOR-05).

```yaml
# Source: existing clusters/k3s-cluster/apps/harbor/helmrelease.yaml lines 122-125
values:
  persistence:
    persistentVolumeClaim:
      database:
        size: 1Gi
        accessMode: ReadWriteOnce
        storageClass: longhorn-replicated  # was: longhorn
```

### Pattern 4: Forgejo App Data storageClass Value

**What:** Forgejo's app data PVC is configured directly in the Forgejo Helm chart values (not via a separate postgresql chart).
**When to use:** For the Forgejo `helmrelease.yaml` (STOR-02).

```yaml
# Source: existing clusters/k3s-cluster/apps/forgejo/helmrelease.yaml lines 29-31
values:
  persistence:
    enabled: true
    storageClass: longhorn-replicated  # was: longhorn
    size: 200Gi
```

### Pattern 5: Adding StorageClass to Flux via Kustomization

**What:** The StorageClass manifest must be included in a Flux Kustomization so it gets applied to the cluster.
**When to use:** When introducing any new cluster-scoped resource via GitOps.

Two placement options:

**Option A — Dedicated `longhorn-config` app directory** (recommended for clarity):
```yaml
# clusters/k3s-cluster/apps/longhorn-config/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - storageclass-replicated.yaml
```
Then add `- apps/longhorn-config` to `clusters/k3s-cluster/kustomization.yaml`.

**Option B — Inline in flux-system** (simpler, but mixes concerns):
Add the raw yaml to `flux-system/` and include it in the flux-system kustomization.

Option A is preferred because it mirrors the existing pattern (each concern has its own `apps/` subdirectory) and makes it easy to add future Longhorn configuration (backup schedules, monitoring, etc.).

### Anti-Patterns to Avoid

- **Setting `longhorn-replicated` as default:** Adding the `is-default-class: true` annotation would make non-critical workloads (ARC runners, Devpi, Loki, Prometheus) use replicated storage unnecessarily, wasting disk space and Longhorn replica rebuild overhead.
- **Using `dataLocality: strict-local`:** Strict-local requires a local replica on the same node as the pod — this defeats fault tolerance, as the volume becomes unavailable if the node goes down.
- **Changing non-critical PVCs:** Do not change `storageClass` for Harbor registry (200Gi), Harbor jobservice, Harbor trivy, Redis, Loki, Prometheus, DevPi, or ARC runners. Only the six PVCs named in STOR-01 through STOR-06 are in scope.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multiple Longhorn StorageClasses | Custom provisioner or CSI plugin | Additional `StorageClass` manifests pointing to `driver.longhorn.io` | Longhorn's CSI driver handles all volume provisioning; the StorageClass is just configuration |
| PVC migration from `longhorn` → `longhorn-replicated` | Data copy scripts, rsync jobs | N/A — new deployments only | All PVCs are for fresh deployments; no data exists to migrate |
| Default StorageClass management | Patching existing classes | Leave `longhorn` as default; new class is opt-in | Kubernetes supports multiple StorageClasses; only one should be annotated as default |

**Key insight:** This phase is purely configuration — no new software components are needed. The only deliverables are YAML manifest changes.

## Common Pitfalls

### Pitfall 1: `numberOfReplicas` as Integer Instead of String

**What goes wrong:** Kubernetes StorageClass parameters must all be strings. Writing `numberOfReplicas: 2` (without quotes) causes a validation error or unexpected behavior.
**Why it happens:** YAML integers look natural but the Longhorn CSI driver requires string parameters.
**How to avoid:** Always quote: `numberOfReplicas: "2"`.
**Warning signs:** `kubectl apply` error mentioning type mismatch in StorageClass parameters.

### Pitfall 2: Accidentally Setting longhorn-replicated as Default

**What goes wrong:** Adding `storageclass.kubernetes.io/is-default-class: "true"` annotation to the new StorageClass causes ALL PVCs without an explicit `storageClass` to use replicated storage, including non-critical workloads.
**Why it happens:** Copy-paste from an example that marks the class as default.
**How to avoid:** Omit the annotation entirely. Only one StorageClass in the cluster should carry this annotation — the existing `longhorn` class.
**Warning signs:** Runner pods start consuming double storage; Prometheus 500Gi PVC now has 2 replicas.

### Pitfall 3: Wrong values.yaml Path for Bitnami PostgreSQL

**What goes wrong:** Using `persistence.storageClass` instead of `primary.persistence.storageClass` in the Bitnami PostgreSQL HelmRelease.
**Why it happens:** Bitnami charts evolved and the primary/readReplicas structure is not obvious.
**How to avoid:** Use `primary.persistence.storageClass` — the existing Forgejo and Keycloak postgres HelmReleases already use `primary.persistence.enabled`, `primary.persistence.storageClass`, `primary.persistence.size`, so follow that same structure.
**Warning signs:** The PVC is provisioned but still uses the default StorageClass; `kubectl get pvc -n forgejo` shows `longhorn` not `longhorn-replicated`.

### Pitfall 4: Smedja Does Not Exist

**What goes wrong:** STOR-06 requires a Smedja PostgreSQL PVC, but no `apps/smedja/` directory exists in the repo.
**Why it happens:** Smedja is a future application referenced in the requirements but not yet deployed.
**How to avoid:** Either (a) create a minimal placeholder `apps/smedja/postgres-helmrelease.yaml` with the correct `longhorn-replicated` StorageClass so STOR-06 is satisfied, or (b) defer STOR-06 if Smedja deployment is not in scope.
**Recommended:** Create the postgres HelmRelease following the same pattern as `apps/forgejo/postgres-helmrelease.yaml` with `size: 10Gi` and `storageClass: longhorn-replicated`, even if the application itself is not deployed yet. The PVC will not be created until a pod claims it. Register the kustomization in the parent only if the namespace also exists. **Flag this for planner decision.**

### Pitfall 5: Confusing Harbor's Internal DB with Bitnami PostgreSQL

**What goes wrong:** Treating Harbor's database PVC the same as Forgejo/Keycloak (Bitnami chart) when it's actually managed by the Harbor Helm chart's own internal PostgreSQL.
**Why it happens:** STOR-05 says "Harbor PostgreSQL PVC" which sounds like Bitnami, but Harbor uses its own bundled database at `persistence.persistentVolumeClaim.database`.
**How to avoid:** Change `database.storageClass` under `persistence.persistentVolumeClaim` in `apps/harbor/helmrelease.yaml`, not a separate postgres HelmRelease.
**Warning signs:** Looking for a `apps/harbor/postgres-helmrelease.yaml` that doesn't exist.

### Pitfall 6: staleReplicaTimeout Value Confusion

**What goes wrong:** Setting `staleReplicaTimeout: "2880"` (48 hours, from old Longhorn examples) when the current default is `"30"` (30 minutes).
**Why it happens:** Many tutorials still show the old 2880 value.
**How to avoid:** Use `"30"` for the replicated class. This means an unhealthy replica is considered stale after 30 minutes, allowing Longhorn to start rebuilding rather than waiting 48 hours.
**Warning signs:** After a node failure, volumes stay degraded for 48 hours before Longhorn begins replica rebuild.

## Code Examples

### Complete StorageClass Manifest

```yaml
# Source: https://longhorn.io/docs/1.11.0/references/storage-class-parameters/
# clusters/k3s-cluster/apps/longhorn-config/storageclass-replicated.yaml
#
# longhorn-replicated StorageClass
#
# Creates a Longhorn storage class with 2-way replication. Use this for critical
# stateful data that must survive a single node failure (databases, git repos).
# The default 'longhorn' class remains unchanged for non-critical workloads.
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-replicated
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "30"
  fsType: "ext4"
```

### Forgejo App Data (STOR-02) — `apps/forgejo/helmrelease.yaml`

```yaml
# Change line 30: storageClass: longhorn → longhorn-replicated
values:
  persistence:
    enabled: true
    storageClass: longhorn-replicated   # was: longhorn
    size: 200Gi
```

### Forgejo PostgreSQL (STOR-03) — `apps/forgejo/postgres-helmrelease.yaml`

```yaml
# Change line 39: storageClass: longhorn → longhorn-replicated
values:
  primary:
    persistence:
      enabled: true
      storageClass: longhorn-replicated  # was: longhorn
      size: 1Gi
```

### Keycloak PostgreSQL (STOR-04) — `apps/keycloak/postgres-helmrelease.yaml`

```yaml
# Change line 39: storageClass: longhorn → longhorn-replicated
values:
  primary:
    persistence:
      enabled: true
      storageClass: longhorn-replicated  # was: longhorn
      size: 1Gi
```

### Harbor Internal Database (STOR-05) — `apps/harbor/helmrelease.yaml`

```yaml
# Change line 125: storageClass: longhorn → longhorn-replicated
values:
  persistence:
    persistentVolumeClaim:
      database:
        size: 1Gi
        accessMode: ReadWriteOnce
        storageClass: longhorn-replicated  # was: longhorn
```

### Smedja PostgreSQL (STOR-06) — `apps/smedja/postgres-helmrelease.yaml` (NEW)

```yaml
# New file — follows pattern from apps/forgejo/postgres-helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: smedja-db
  namespace: flux-system
spec:
  interval: 5m
  targetNamespace: smedja
  install:
    createNamespace: false
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  chart:
    spec:
      chart: postgresql
      version: 18.1.13  # Match version used by forgejo-db and keycloak-db
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: flux-system
  values:
    fullnameOverride: smedja-postgresql
    global:
      postgresql:
        auth:
          username: smedja
          database: smedja
          existingSecret: smedja-db-credentials
          secretKeys:
            adminPasswordKey: postgres-password
            userPasswordKey: password
    primary:
      persistence:
        enabled: true
        storageClass: longhorn-replicated
        size: 10Gi
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi
```

### Kustomization for longhorn-config (STOR-01)

```yaml
# clusters/k3s-cluster/apps/longhorn-config/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - storageclass-replicated.yaml
```

### Top-level Kustomization Addition

```yaml
# clusters/k3s-cluster/kustomization.yaml — add longhorn-config entry
resources:
  - flux-system
  - apps/longhorn-config   # NEW: Longhorn StorageClass configuration
  - apps/harbor
  - apps/keycloak
  ...
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `staleReplicaTimeout: "2880"` (48h) in examples | `staleReplicaTimeout: "30"` (30min) is now the documented default | Longhorn 1.5+ docs | Faster replica rebuilds after node failure |
| Longhorn v1 API | Longhorn 1.11.x with v2 data engine (technical preview) | 2024-2025 | v2 data engine not stable for production; stick with default |
| `helm.toolkit.fluxcd.io/v2beta2` | `helm.toolkit.fluxcd.io/v2` | Flux v2.2+ | Already using v2 in this repo |

**Deprecated/outdated:**
- `staleReplicaTimeout: "2880"`: Still appears in old tutorials but documentation default is now 30 minutes.
- `helm.toolkit.fluxcd.io/v2beta2`: Superseded by `v2`; repo already uses `v2` correctly.

## Open Questions

1. **How to handle STOR-06 (Smedja PostgreSQL)?**
   - What we know: Smedja is mentioned in requirements with a 10Gi PVC; no `apps/smedja/` exists; Bitnami postgresql 18.1.13 is already a registered chart source
   - What's unclear: Does the planner create a postgres-only HelmRelease without the full Smedja application? Does this phase scope include the namespace + kustomization + parent registration?
   - Recommendation: Create `apps/smedja/namespace.yaml`, `apps/smedja/postgres-helmrelease.yaml`, and `apps/smedja/kustomization.yaml`. Register in parent kustomization. This satisfies STOR-06 and sets the stage for Smedja's full deployment later. The postgres HelmRelease will be in a Ready=False state (waiting for secret) until the Smedja secret is created imperatively — this is the same pattern as other databases.

2. **Which Longhorn version is running on the cluster?**
   - What we know: Longhorn is deployed via a separate `infra-core` repository (not this repo); the StorageClass parameters are stable across 1.3-1.11+
   - What's unclear: Exact Longhorn version; whether v2 data engine is enabled
   - Recommendation: Use the conservative parameter set (`numberOfReplicas: "2"`, `staleReplicaTimeout: "30"`, `fsType: "ext4"`, no v2-specific options). These parameters are compatible with all Longhorn versions from 1.2 onward.

3. **Should Harbor's registry PVC (200Gi) also be replicated?**
   - What we know: Requirements scope is specifically STOR-01 through STOR-06; Harbor's registry is not named
   - What's unclear: Intent — the registry stores built images and is large; losing it is painful
   - Recommendation: Out of scope per STOR requirements. Harbor registry, jobservice, and trivy PVCs stay on `longhorn` (single replica). Only the `database` PVC is in scope (STOR-05).

## Validation Architecture

> nyquist_validation is not set in config.json — skip automated test section.

This is a GitOps infrastructure phase. Validation is manual and command-based:

### Verification Commands

```bash
# Verify StorageClass exists with correct replica count
kubectl get storageclass longhorn-replicated -o jsonpath='{.parameters.numberOfReplicas}'
# Expected output: 2

# Verify default StorageClass is unchanged
kubectl get storageclass -o=custom-columns=NAME:.metadata.name,DEFAULT:.metadata.annotations.'storageclass\.kubernetes\.io/is-default-class'
# Expected: longhorn=true, longhorn-replicated=(none/false)

# Verify Forgejo app data PVC
kubectl get pvc -n forgejo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.storageClassName}{"\n"}{end}'
# Expected: forgejo (app data PVC) → longhorn-replicated, forgejo-postgresql-... → longhorn-replicated

# Verify Keycloak PostgreSQL PVC
kubectl get pvc -n keycloak -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.storageClassName}{"\n"}{end}'
# Expected: keycloak-postgresql-... → longhorn-replicated

# Verify Harbor database PVC
kubectl get pvc -n harbor -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.storageClassName}{"\n"}{end}'
# Expected: harbor-database → longhorn-replicated; harbor-registry, harbor-jobservice, harbor-trivy → longhorn (unchanged)

# Verify Longhorn sees 2 replicas for each replicated volume
# (requires kubectl access to longhorn-system namespace)
kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.numberOfReplicas}{"\n"}{end}'
```

## Sources

### Primary (HIGH confidence)

- [Longhorn Storage Class Parameters](https://longhorn.io/docs/1.11.0/references/storage-class-parameters/) — `numberOfReplicas`, `staleReplicaTimeout`, `fsType`, `dataLocality` parameter definitions and defaults
- [Longhorn examples/storageclass.yaml (GitHub)](https://github.com/longhorn/longhorn/blob/master/examples/storageclass.yaml) — canonical example StorageClass YAML
- Existing codebase analysis: `clusters/k3s-cluster/apps/forgejo/helmrelease.yaml`, `postgres-helmrelease.yaml`, `clusters/k3s-cluster/apps/keycloak/postgres-helmrelease.yaml`, `clusters/k3s-cluster/apps/harbor/helmrelease.yaml` — direct inspection of all six PVCs' current values paths

### Secondary (MEDIUM confidence)

- [Bitnami PostgreSQL charts/values.yaml (GitHub)](https://github.com/bitnami/charts/blob/main/bitnami/postgresql/values.yaml) — confirmed `primary.persistence.storageClass` is the correct path for Bitnami postgresql 18.x
- [Longhorn Storage Class Parameters - philprime.dev](https://philprime.dev/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-18.html) — additional StorageClass configuration examples cross-verified with official docs

### Tertiary (LOW confidence)

- General WebSearch results on Flux GitOps StorageClass patterns — consistent with existing repo patterns observed directly

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Longhorn CSI provisioner and StorageClass API are stable; Bitnami chart path verified against existing HelmReleases in repo
- Architecture: HIGH — directly derived from existing file structure in codebase
- Pitfalls: HIGH — numberOfReplicas quoting and Bitnami path are verified against official chart values; Smedja absence confirmed by repo search

**Research date:** 2026-02-28
**Valid until:** 2026-03-30 (Longhorn StorageClass API is stable; parameters don't change between minor versions)
