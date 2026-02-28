# Phase 2: Scheduling Constraints - Research

**Researched:** 2026-02-28
**Domain:** Kubernetes scheduling — nodeSelector, nodeAffinity, topologySpreadConstraints, pod anti-affinity in Flux HelmReleases
**Confidence:** HIGH

---

## Summary

Phase 2 applies scheduling constraints across two workload categories: ARC runner scale sets (6 confirmed HelmReleases) and stateful applications (Forgejo, Harbor, Keycloak, and their PostgreSQL backends). Every constraint lives inside Helm `values:` blocks in existing HelmRelease files — no new Kubernetes resources are needed.

The label key established in Phase 1 is `node-role` (not `role`). This is locked by the Phase 1 CONTEXT.md decision and is the key Phase 2 scheduling manifests must use. REQUIREMENTS.md incorrectly lists `role=runners` — the correct label is `node-role=runners`.

The gha-runner-scale-set chart fully supports native Kubernetes pod scheduling fields under `template.spec` (nodeSelector, affinity, topologySpreadConstraints). All three Bitnami PostgreSQL instances use chart version 18.1.13 which supports `primary.nodeSelector`, `primary.nodeAffinityPreset.*`, `primary.affinity`, and `primary.topologySpreadConstraints`. The Harbor Helm chart (goharbor/harbor-helm) supports `database.nodeSelector`, `database.affinity`, and `database.topologySpreadConstraints` per component. The Forgejo chart exposes top-level `nodeSelector`, `affinity`, and `topologySpreadConstraints` fields. The Keycloak (codecentric/keycloakx) chart supports `nodeSelector` as a native YAML object and `affinity` as a rendered template string.

**Primary recommendation:** Add `template.spec.nodeSelector` and `template.spec.topologySpreadConstraints` to all 6 ARC runner HelmReleases. Add `primary.nodeAffinityPreset.*` (or `primary.affinity`) and `primary.podAntiAffinityPreset: hard` to all PostgreSQL HelmReleases. Add `nodeSelector`/`affinity` to Forgejo, Harbor, and Keycloak HelmReleases targeting their respective node roles.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RNRS-01 | All 7 ARC runner scale sets have topologySpreadConstraints with key `kubernetes.io/hostname` | `template.spec.topologySpreadConstraints` is standard Kubernetes PodSpec supported by the gha-runner-scale-set chart under `template.spec` |
| RNRS-02 | Runner scale sets have nodeSelector pinning runners to `node-role=runners` nodes | `template.spec.nodeSelector` is supported natively by the gha-runner-scale-set chart; key is `node-role` per Phase 1 locked decision |
| SCHED-01 | Stateful workloads (databases, Forgejo, Harbor) have nodeAffinity targeting appropriate node roles | Forgejo: top-level `affinity` field; Harbor: `database.affinity`, `core.affinity`, etc.; Bitnami PostgreSQL: `primary.nodeAffinityPreset.*` or `primary.affinity` |
| SCHED-02 | PostgreSQL instances have pod anti-affinity preventing co-location | Bitnami PostgreSQL: `primary.podAntiAffinityPreset: hard` (or `primary.affinity` with custom podAntiAffinity block) |
| SCHED-03 | Application pods have topologySpreadConstraints to spread across nodes | Forgejo: top-level `topologySpreadConstraints`; Harbor: per-component `topologySpreadConstraints`; Keycloak: `topologySpreadConstraints` (template string) |
</phase_requirements>

---

## Inventory: What Needs To Change

### ARC Runner Scale Sets (6 confirmed, requirements say 7)

| HelmRelease Name | File | Chart |
|-----------------|------|-------|
| arc-runner-set | runner-scale-set-helmrelease.yaml | gha-runner-scale-set 0.13.1 |
| claude-runner-set | claude-scale-set-helmrelease.yaml | gha-runner-scale-set 0.13.1 |
| code-quality-runner | code-quality-runner-helmrelease.yaml | gha-runner-scale-set 0.13.1 |
| dependabot | dependabot-runner-scale-set-helmrelease.yaml | gha-runner-scale-set 0.13.1 |
| modbus-runner-set | modbus-runner-set.yaml | gha-runner-scale-set 0.13.1 |
| opcua-runner-set | opcua-runner-set.yaml | gha-runner-scale-set 0.13.1 |

**Note on "7th" runner:** RNRS-01 and RNRS-02 reference "all 7 ARC runner scale sets" but only 6 HelmReleases are present in the kustomization.yaml and directory. The operator HelmRelease (`gha-runner-scale-set-controller`) is NOT a runner scale set and does not need runner scheduling constraints. The planner should target the 6 confirmed runner scale set HelmReleases. If a 7th is added later, the same pattern applies.

### Stateful Workloads

| Workload | HelmRelease File | Chart | Target Node Role |
|----------|-----------------|-------|-----------------|
| Forgejo app | forgejo/helmrelease.yaml | forgejo 16.1.0 | apps |
| Forgejo PostgreSQL | forgejo/postgres-helmrelease.yaml | bitnami/postgresql 18.1.13 | apps |
| Keycloak app | keycloak/helmrelease.yaml | codecentric/keycloakx 7.1.5 | infra |
| Keycloak PostgreSQL | keycloak/postgres-helmrelease.yaml | bitnami/postgresql 18.1.13 | infra |
| Harbor app | harbor/helmrelease.yaml | harbor 1.18.1 (goharbor) | apps |
| Harbor internal DB | harbor/helmrelease.yaml (database section) | harbor 1.18.1 (embedded) | apps |

**Note on Smedja:** STOR-06 references a Smedja PostgreSQL PVC but no Smedja app or HelmRelease exists in this repo. Smedja is out of scope for Phase 2 — SCHED-02 applies only to the 3 existing PostgreSQL instances (forgejo-db, keycloak-db, harbor internal db).

---

## Standard Stack

### Core (no new libraries needed)

| Mechanism | Kubernetes API | Purpose | Why Standard |
|-----------|---------------|---------|--------------|
| `nodeSelector` | Pod spec | Hard-require specific node labels | Simplest, lowest overhead; appropriate for role pinning |
| `nodeAffinity` | Pod spec | Required or preferred node label matching with operators | Needed when using `In`/`NotIn` operators or expressing "prefer this role" |
| `topologySpreadConstraints` | Pod spec | Distribute pods across topology domains (nodes) | The Kubernetes-native way to prevent same-node co-location since K8s 1.19 |
| `podAntiAffinity` | Pod spec | Prevent two pods from landing on same node | Correct tool for stateful pod separation |

### No New Helm Charts or Tools Required

All changes are Helm `values:` additions to existing HelmReleases managed by Flux. No new CRDs, no new operators, no new HelmRepositories.

---

## Architecture Patterns

### Pattern 1: ARC Runner nodeSelector + topologySpreadConstraints

**What:** Add two blocks under `template.spec` in each runner HelmRelease — `nodeSelector` pins to runners nodes, `topologySpreadConstraints` ensures runners of the same set spread across different nodes.

**When to use:** All 6 runner scale set HelmReleases.

**Example:**
```yaml
# In HelmRelease values:
template:
  spec:
    nodeSelector:
      node-role: runners
    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: <runner-scale-set-name>
```

**Important: labelSelector for ARC runners.** The `labelSelector` in `topologySpreadConstraints` must match the labels the chart applies to runner pods. The gha-runner-scale-set chart applies `app.kubernetes.io/name: <runnerScaleSetName>` to pods. Verify by checking chart templates or use `ScheduleAnyway` (soft) rather than `DoNotSchedule` to avoid runners getting stuck pending when there are fewer runner nodes than runners.

**whenUnsatisfiable choice — ScheduleAnyway vs DoNotSchedule:**
- `DoNotSchedule` (hard): pods stay Pending if constraint cannot be satisfied. Risk: if there is only 1 runner node and maxRunners > 1, all runners above 1 will Pending.
- `ScheduleAnyway` (soft): scheduler still prefers spreading but allows co-location. Safer for dynamic scale-to-zero runner pools.
- **Recommendation:** Use `ScheduleAnyway` because runners scale to 0 and may burst onto a small number of nodes. This is a best-effort spread, not a hard guarantee.

### Pattern 2: Bitnami PostgreSQL Anti-Affinity (pod anti-affinity using presets)

**What:** Use Bitnami's built-in `podAntiAffinityPreset` to prevent two DB pods from sharing a node. Use `nodeAffinityPreset` to pin to the correct role.

**When to use:** forgejo-db and keycloak-db HelmReleases.

**Example:**
```yaml
# In HelmRelease values:
primary:
  nodeAffinityPreset:
    type: "hard"
    key: "node-role"
    values:
      - apps         # for forgejo-db
      # OR
      - infra        # for keycloak-db
  podAntiAffinityPreset: hard
```

**How `podAntiAffinityPreset: hard` works:** The Bitnami common library generates a `requiredDuringSchedulingIgnoredDuringExecution` podAntiAffinity rule using the chart's own selector labels. For a single-replica PostgreSQL (which all instances here are), this actually has no effect — anti-affinity requires 2+ pods to prevent co-location. However, it documents intent and will correctly prevent co-location if replicas are ever scaled up.

**Alternative with explicit affinity block:**
```yaml
primary:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-role
                operator: In
                values:
                  - apps
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app.kubernetes.io/name: postgresql
          topologyKey: kubernetes.io/hostname
```
Note: When `primary.affinity` is set, `primary.nodeAffinityPreset` and `primary.podAntiAffinityPreset` are both ignored. Use one approach, not both.

### Pattern 3: Forgejo App nodeSelector + topologySpreadConstraints

**What:** Add top-level `nodeSelector` and `affinity` (or `topologySpreadConstraints`) to Forgejo HelmRelease values.

**Example:**
```yaml
# In HelmRelease values:
nodeSelector:
  node-role: apps

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: node-role
              operator: In
              values:
                - apps
```

Or using `nodeSelector` alone for simplicity (since nodeSelector is equivalent to hard nodeAffinity with `In` operator):
```yaml
nodeSelector:
  node-role: apps
```

### Pattern 4: Harbor nodeSelector + affinity (per component)

**What:** Harbor's goharbor/harbor-helm chart supports per-component scheduling. For Phase 2, target the `database` component (internal postgres). The broader Harbor application components (core, portal, registry, jobservice) can share a single top-level nodeSelector via each component block.

**Example:**
```yaml
# In Harbor HelmRelease values:
core:
  nodeSelector:
    node-role: apps
portal:
  nodeSelector:
    node-role: apps
jobservice:
  nodeSelector:
    node-role: apps
registry:
  nodeSelector:
    node-role: apps
database:
  internal:
    nodeSelector:
      node-role: apps
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                component: database
            topologyKey: kubernetes.io/hostname
trivy:
  nodeSelector:
    node-role: apps
nginx:
  nodeSelector:
    node-role: apps
```

**Harbor database anti-affinity consideration:** The Harbor chart uses an internal PostgreSQL (not a separate Bitnami chart). It is a single-replica stateful set. The pod anti-affinity rule will document intent but has no real scheduling effect at replica=1.

### Pattern 5: Keycloak nodeSelector + affinity (template strings)

**What:** The codecentric/keycloakx chart renders `affinity` and `topologySpreadConstraints` as Go template strings (using `tpl`). They must be provided as YAML multi-line strings, not native YAML objects.

**Example:**
```yaml
# In Keycloak HelmRelease values:
nodeSelector:
  node-role: infra

affinity: |
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: node-role
              operator: In
              values:
                - infra
```

**Critical:** The default `affinity` in keycloakx already includes a `podAntiAffinity` block. When overriding `affinity`, you replace the entire default. If you want both nodeAffinity AND the existing podAntiAffinity, you must include both in the override string.

**The simpler option for Keycloak:** Use only `nodeSelector` for node role pinning (Keycloak is a single-replica deployment). This avoids rewriting the default affinity template, which already handles pod anti-affinity correctly.

### Anti-Patterns to Avoid

- **Hard topologySpreadConstraints on runner sets with scale-to-zero:** `DoNotSchedule` will leave runners Pending if there are fewer nodes labeled `node-role=runners` than the runner count. Use `ScheduleAnyway`.
- **Setting both `primary.affinity` AND `primary.nodeAffinityPreset`:** Bitnami ignores the preset when custom affinity is set. Pick one approach per HelmRelease.
- **Overriding Keycloak `affinity` without including its default podAntiAffinity:** The default already has useful inter-pod anti-affinity. Preserve it or intentionally replace it.
- **Adding scheduling constraints before Phase 1 labels are applied:** Manifests will be valid but pods will stay Pending until `node-role` labels exist on nodes. This is an operational sequencing concern, not a manifest error.
- **Using `role` instead of `node-role` as the label key:** REQUIREMENTS.md has an error (`role=runners`). Phase 1 CONTEXT.md locked the key as `node-role`. All Phase 2 manifests must use `node-role`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Node role pinning | Custom webhook or admission controller | `nodeSelector: {node-role: runners}` in pod spec | Kubernetes scheduler handles this natively |
| Spread across nodes | Custom scheduling logic | `topologySpreadConstraints` | Standard Kubernetes API since 1.19, stable since 1.24 |
| PostgreSQL placement | Custom operator logic | Bitnami `primary.nodeAffinityPreset` | Chart already exposes presets for common patterns |
| Cross-replica anti-affinity | Custom pod assignment | `podAntiAffinityPreset: hard` | Bitnami common library generates correct RBAC-safe rules |

**Key insight:** Every scheduling capability needed for Phase 2 is a native Kubernetes pod spec field. No new tooling is required. All changes are values additions to existing Flux HelmReleases.

---

## Common Pitfalls

### Pitfall 1: Label Key Mismatch (node-role vs role)
**What goes wrong:** Using `role=runners` (as in REQUIREMENTS.md) instead of `node-role=runners` (as in Phase 1 CONTEXT.md). Pods will stay Pending with "no nodes match nodeSelector."
**Why it happens:** REQUIREMENTS.md was written before Phase 1 locked the label key.
**How to avoid:** Use `node-role` in all nodeSelector, nodeAffinity, and topologySpreadConstraints definitions.
**Warning signs:** Pods in Pending state with FailedScheduling events mentioning label mismatch.

### Pitfall 2: Hard topologySpreadConstraint Blocks Scale-Out
**What goes wrong:** `whenUnsatisfiable: DoNotSchedule` with `maxSkew: 1` on a runner set when there is only 1 node labeled `node-role=runners`. The 2nd runner pod stays Pending because it cannot spread.
**Why it happens:** Runner sets can scale from 0 to maxRunners; the number of runner nodes may be 1-2 while maxRunners is 6-10.
**How to avoid:** Use `whenUnsatisfiable: ScheduleAnyway` for runner sets.
**Warning signs:** Runner pods in Pending state; GitHub Actions jobs queued but not starting.

### Pitfall 3: Harbor Component Coverage
**What goes wrong:** Adding `nodeSelector` to only the `database` section while forgetting `core`, `portal`, `registry`, `jobservice`, `trivy`, `nginx` — Harbor pods scatter across all nodes.
**Why it happens:** Harbor has many components, each needing its own scheduling block.
**How to avoid:** Add `nodeSelector: {node-role: apps}` to every Harbor component block.
**Warning signs:** Harbor pods running on infra or runner nodes; check `kubectl get pods -n harbor -o wide`.

### Pitfall 4: Keycloak affinity Override Wipes Default podAntiAffinity
**What goes wrong:** Setting `affinity: |` in Keycloak values with only `nodeAffinity` — this replaces the chart's default podAntiAffinity which prevents Keycloak pods from co-locating.
**Why it happens:** The `affinity` value in keycloakx is a whole block replacement, not a merge.
**How to avoid:** Either (a) use only `nodeSelector` for role pinning without touching `affinity`, or (b) include both nodeAffinity and the default podAntiAffinity rules in the override.

### Pitfall 5: PostgreSQL Anti-affinity Has No Effect at Replica=1
**What goes wrong:** Setting `podAntiAffinityPreset: hard` and expecting it to spread DBs across nodes — it won't, because anti-affinity only constrains pod-to-pod placement and each DB has only 1 replica.
**Why it happens:** Pod anti-affinity means "don't schedule me on a node where another pod with these labels is already running." With 1 replica per DB, there are never two pods of the same DB.
**How to avoid:** Recognize the intent is correct (prevents co-location if scaled) even though it has no effect at replica=1. Do not confuse this with inter-DB anti-affinity (preventing forgejo-db and keycloak-db from sharing a node — that requires cross-namespace affinity or just nodeSelector to separate roles).
**Warning signs:** None — this is a semantic expectation mismatch, not a runtime failure.

---

## Code Examples

Verified patterns from official sources and current chart documentation:

### ARC Runner Scale Set: nodeSelector + topologySpreadConstraints
```yaml
# File: clusters/k3s-cluster/apps/actions-runner-controller/runner-scale-set-helmrelease.yaml
# Add inside values.template.spec alongside existing securityContext and containers
values:
  template:
    spec:
      nodeSelector:
        node-role: runners
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: arc-runner-set
      securityContext:
        fsGroup: 1001
      containers:
        # ... existing containers unchanged
```

### Bitnami PostgreSQL: nodeAffinityPreset + podAntiAffinityPreset
```yaml
# File: clusters/k3s-cluster/apps/forgejo/postgres-helmrelease.yaml
values:
  primary:
    nodeAffinityPreset:
      type: "hard"
      key: "node-role"
      values:
        - apps
    podAntiAffinityPreset: hard
    persistence:
      # ... existing unchanged
```

### Forgejo App: nodeSelector
```yaml
# File: clusters/k3s-cluster/apps/forgejo/helmrelease.yaml
values:
  nodeSelector:
    node-role: apps
  persistence:
    # ... existing unchanged
```

### Harbor: Per-component nodeSelector
```yaml
# File: clusters/k3s-cluster/apps/harbor/helmrelease.yaml
values:
  core:
    nodeSelector:
      node-role: apps
  portal:
    nodeSelector:
      node-role: apps
  jobservice:
    nodeSelector:
      node-role: apps
  registry:
    nodeSelector:
      node-role: apps
  database:
    internal:
      nodeSelector:
        node-role: apps
  trivy:
    nodeSelector:
      node-role: apps
  nginx:
    nodeSelector:
      node-role: apps
  exporter:
    nodeSelector:
      node-role: apps
  # ... existing values unchanged
```

### Keycloak: nodeSelector (minimal, preserves default affinity)
```yaml
# File: clusters/k3s-cluster/apps/keycloak/helmrelease.yaml
values:
  nodeSelector:
    node-role: infra
  # leave affinity at default (it has correct podAntiAffinity built in)
  # ... existing values unchanged
```

### Keycloak PostgreSQL: nodeAffinityPreset + podAntiAffinityPreset
```yaml
# File: clusters/k3s-cluster/apps/keycloak/postgres-helmrelease.yaml
values:
  primary:
    nodeAffinityPreset:
      type: "hard"
      key: "node-role"
      values:
        - infra
    podAntiAffinityPreset: hard
    persistence:
      # ... existing unchanged
```

---

## Open Questions

1. **The 7th runner scale set**
   - What we know: 6 runner scale set HelmReleases exist in the kustomization.yaml. RNRS-01/RNRS-02 say "all 7."
   - What's unclear: Whether a 7th runner set is planned, already exists but not in kustomization, or the requirements count is wrong.
   - Recommendation: Apply constraints to all 6 confirmed runner HelmReleases. Note the discrepancy in the plan.

2. **Harbor database: internal vs external PostgreSQL**
   - What we know: Harbor uses `database.type: internal` with a Harbor-bundled PostgreSQL image (not Bitnami). The `database.internal.nodeSelector` field exists in the harbor-helm chart.
   - What's unclear: Whether `database.internal` supports a full `affinity` block or just `nodeSelector`.
   - Recommendation: Use `database.internal.nodeSelector: {node-role: apps}` for Harbor's DB. Skip anti-affinity for Harbor's internal DB (it's single-replica and the chart nesting may not support it cleanly).

3. **ARC runner topologySpreadConstraints labelSelector values**
   - What we know: The gha-runner-scale-set chart sets pod labels but exact label keys need chart template verification.
   - What's unclear: The exact label key/value the chart applies to runner pods (likely `app.kubernetes.io/name: <runnerScaleSetName>` or `actions.github.com/scale-set-name: <name>`).
   - Recommendation: Use `ScheduleAnyway` to mitigate mismatch risk. The planner should either verify chart labels via `helm template` or use a broad `matchLabels` that matches the `runnerScaleSetName` value.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `nodeSelector` only | `topologySpreadConstraints` for spread | K8s 1.24 (stable) | More expressive, replaces manual pod placement anti-patterns |
| `podAffinity: hard` for distribution | `topologySpreadConstraints: maxSkew: 1` | K8s 1.19+ | Topology spread is more declarative and does not require knowing other pod names |
| Bitnami `affinity` raw block | `nodeAffinityPreset` + `podAntiAffinityPreset` | Bitnami charts v10+ | Preset approach reduces YAML verbosity for common patterns |

---

## Sources

### Primary (HIGH confidence)
- Phase 1 CONTEXT.md — Locked label key `node-role`, role assignment (infra/apps/runners)
- Codebase audit — 6 runner HelmReleases confirmed, chart versions verified, existing `template.spec` structure inspected
- [github.com/actions/actions-runner-controller issues/2984](https://github.com/actions/actions-runner-controller/issues/2984) — Confirms `template.spec` accepts full pod scheduling fields including `nodeSelector`, `affinity`, `topologySpreadConstraints`
- [github.com/bitnami/charts postgresql/values.yaml](https://github.com/bitnami/charts/blob/main/bitnami/postgresql/values.yaml) — `primary.nodeAffinityPreset.*`, `primary.podAntiAffinityPreset`, `primary.affinity`, `primary.nodeSelector` fields confirmed
- [github.com/goharbor/harbor-helm values.yaml](https://github.com/goharbor/harbor-helm/blob/main/values.yaml) — Per-component `nodeSelector`, `affinity`, `topologySpreadConstraints` confirmed for all components including `database`
- [code.forgejo.org forgejo-helm values.yaml](https://code.forgejo.org/forgejo-contrib/forgejo-helm/src/branch/main/values.yaml) — Top-level `nodeSelector`, `affinity`, `topologySpreadConstraints` confirmed
- [github.com/codecentric/helm-charts keycloakx/values.yaml](https://github.com/codecentric/helm-charts/blob/master/charts/keycloakx/values.yaml) — `nodeSelector` as native YAML object; `affinity` as rendered template string confirmed

### Secondary (MEDIUM confidence)
- Kubernetes official docs patterns for `topologySpreadConstraints` syntax and `whenUnsatisfiable` semantics — verified against multiple sources

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new tools needed, all native Kubernetes fields
- Architecture: HIGH — chart APIs verified against official values.yaml files
- Pitfalls: HIGH — most are structural facts (label key, affinity override behavior) verified from source

**Research date:** 2026-02-28
**Valid until:** 2026-03-30 (chart versions pinned; Helm values API is stable)
