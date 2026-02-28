---
phase: 02-scheduling-constraints
verified: 2026-02-28T00:00:00Z
status: passed
score: 13/13 must-haves verified
re_verification: false
---

# Phase 2: Scheduling Constraints Verification Report

**Phase Goal:** All 7 ARC runner scale sets and stateful workloads are scheduled according to node roles with topology spread
**Verified:** 2026-02-28
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Note on "7 ARC runner scale sets"

REQUIREMENTS.md RNRS-01 and the ROADMAP.md Phase 2 Success Criterion both reference "7 ARC runner scale sets." The actual codebase contains only **6 runner scale set HelmReleases**:

- arc-runner-set
- claude-runner-set
- code-quality-runner
- dependabot
- modbus-runner-set
- opcua-runner-set

The seventh entry in the `actions-runner-controller/` directory is `operator-helmrelease.yaml`, which deploys the `gha-runner-scale-set-controller` (the ARC operator itself), not a runner scale set. This is correctly excluded from scheduling constraints — the controller manages runners but does not run job workloads. All 6 runner scale sets are accounted for and fully constrained. The "7" figure in the requirements is a documentation error noted in SUMMARY 02-01.

---

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | All 6 runner HelmReleases have `template.spec.nodeSelector: {node-role: runners}` | VERIFIED | Confirmed in all 6 files: `nodeSelector:\n  node-role: runners` present inside `template.spec` |
| 2 | All 6 runner HelmReleases have `topologySpreadConstraints` with `topologyKey: kubernetes.io/hostname` and `whenUnsatisfiable: ScheduleAnyway` | VERIFIED | All 6 files contain `topologyKey: kubernetes.io/hostname` and `whenUnsatisfiable: ScheduleAnyway` |
| 3 | Each runner `topologySpreadConstraints.labelSelector.matchLabels.app.kubernetes.io/name` matches the `runnerScaleSetName` in that file | VERIFIED | arc-runner-set, claude-runner-set, code-quality-runner, dependabot, modbus-runner-set, opcua-runner-set all match |
| 4 | The label key used is `node-role` (not `role`) throughout all runner files | VERIFIED | No bare `role:` label key found; all files use `node-role: runners` |
| 5 | forgejo-db PostgreSQL is pinned to nodes labeled `node-role=apps` via hard nodeAffinity | VERIFIED | `primary.nodeAffinityPreset.type: "hard"`, `key: "node-role"`, `values: [apps]` confirmed |
| 6 | keycloak-db PostgreSQL is pinned to nodes labeled `node-role=infra` via hard nodeAffinity | VERIFIED | `primary.nodeAffinityPreset.type: "hard"`, `key: "node-role"`, `values: [infra]` confirmed |
| 7 | Both PostgreSQL HelmReleases have `podAntiAffinityPreset: hard` | VERIFIED | Both forgejo and keycloak postgres-helmrelease.yaml contain `podAntiAffinityPreset: hard` |
| 8 | Neither PostgreSQL file has a `primary.affinity` block (would shadow the presets) | VERIFIED | No `affinity:` key found in either postgres file |
| 9 | Forgejo app pod is pinned to `node-role=apps` via top-level `nodeSelector` | VERIFIED | `nodeSelector:\n  node-role: apps` at `values` root in forgejo/helmrelease.yaml |
| 10 | Forgejo app HelmRelease has `topologySpreadConstraints` with `topologyKey: kubernetes.io/hostname` and `whenUnsatisfiable: ScheduleAnyway` | VERIFIED | Present at `values` root level with `app.kubernetes.io/name: forgejo` labelSelector |
| 11 | Keycloak app pod is pinned to `node-role=infra` via top-level `nodeSelector`, with no affinity override | VERIFIED | `nodeSelector:\n  node-role: infra` at `values` root; no `affinity:` key present |
| 12 | All 8 Harbor component sections have `nodeSelector: {node-role: apps}` | VERIFIED | Count of `node-role: apps` in harbor/helmrelease.yaml is **8** (core, portal, jobservice, registry, nginx, database.internal, trivy, exporter) |
| 13 | No Harbor component uses the wrong label key | VERIFIED | No bare `role:` key found; all occurrences are `node-role: apps` |

**Score:** 13/13 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `clusters/k3s-cluster/apps/actions-runner-controller/runner-scale-set-helmrelease.yaml` | arc-runner-set scheduling constraints | VERIFIED | nodeSelector + topologySpreadConstraints present; labelSelector: arc-runner-set |
| `clusters/k3s-cluster/apps/actions-runner-controller/claude-scale-set-helmrelease.yaml` | claude-runner-set scheduling constraints | VERIFIED | nodeSelector + topologySpreadConstraints present; labelSelector: claude-runner-set |
| `clusters/k3s-cluster/apps/actions-runner-controller/code-quality-runner-helmrelease.yaml` | code-quality-runner scheduling constraints | VERIFIED | nodeSelector + topologySpreadConstraints present; labelSelector: code-quality-runner |
| `clusters/k3s-cluster/apps/actions-runner-controller/dependabot-runner-scale-set-helmrelease.yaml` | dependabot runner scheduling constraints | VERIFIED | nodeSelector + topologySpreadConstraints present before dnsPolicy; dnsConfig, initContainers, dind container all preserved |
| `clusters/k3s-cluster/apps/actions-runner-controller/modbus-runner-set.yaml` | modbus-runner-set scheduling constraints | VERIFIED | nodeSelector + topologySpreadConstraints present; labelSelector: modbus-runner-set |
| `clusters/k3s-cluster/apps/actions-runner-controller/opcua-runner-set.yaml` | opcua-runner-set scheduling constraints | VERIFIED | nodeSelector + topologySpreadConstraints present; labelSelector: opcua-runner-set |
| `clusters/k3s-cluster/apps/forgejo/postgres-helmrelease.yaml` | forgejo-db node affinity and pod anti-affinity | VERIFIED | primary.nodeAffinityPreset (hard, node-role, apps) + podAntiAffinityPreset: hard; no conflicting affinity block |
| `clusters/k3s-cluster/apps/keycloak/postgres-helmrelease.yaml` | keycloak-db node affinity and pod anti-affinity | VERIFIED | primary.nodeAffinityPreset (hard, node-role, infra) + podAntiAffinityPreset: hard; no conflicting affinity block |
| `clusters/k3s-cluster/apps/forgejo/helmrelease.yaml` | Forgejo app node pinning and topology spread | VERIFIED | nodeSelector: {node-role: apps} + topologySpreadConstraints at values root |
| `clusters/k3s-cluster/apps/keycloak/helmrelease.yaml` | Keycloak app node pinning | VERIFIED | nodeSelector: {node-role: infra} at values root; no affinity override; no topologySpreadConstraints (correct for single-replica + tpl-rendered affinity) |
| `clusters/k3s-cluster/apps/harbor/helmrelease.yaml` | Harbor per-component nodeSelector for all components | VERIFIED | 8 occurrences of `node-role: apps`; all 8 components covered |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `template.spec.nodeSelector: {node-role: runners}` | `node-role=runners` label on runner nodes | Kubernetes scheduler nodeSelector matching | WIRED | Pattern `node-role: runners` confirmed in all 6 runner files |
| `template.spec.topologySpreadConstraints[].topologyKey` | `kubernetes.io/hostname` topology domain | `topologyKey` field | WIRED | `topologyKey: kubernetes.io/hostname` confirmed in all 6 runner files |
| `primary.nodeAffinityPreset.key` | `node-role` label on cluster nodes | Bitnami chart nodeAffinityPreset rendering | WIRED | `key: "node-role"` present in both postgres files; no conflicting `primary.affinity` block that would shadow presets |
| `primary.podAntiAffinityPreset` | other PostgreSQL pods | Bitnami common library podAntiAffinity generation | WIRED | `podAntiAffinityPreset: hard` confirmed in both postgres files |
| `forgejo helmrelease nodeSelector` | `node-role=apps` label on cluster nodes | Kubernetes scheduler | WIRED | `node-role: apps` at values root in forgejo/helmrelease.yaml |
| `keycloak helmrelease nodeSelector` | `node-role=infra` label on cluster nodes | Kubernetes scheduler | WIRED | `node-role: infra` at values root in keycloak/helmrelease.yaml; no affinity override that would conflict |
| `core.nodeSelector, portal.nodeSelector, ... (8 components)` | `node-role=apps` label on cluster nodes | goharbor/harbor-helm per-component scheduling | WIRED | All 8 component-level nodeSelectors present; `node-role: apps` count = 8 confirmed |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| RNRS-01 | 02-01-PLAN | All 7 ARC runner scale sets have topologySpreadConstraints with key `kubernetes.io/hostname` | SATISFIED (with note) | All 6 existing runner scale sets have topologySpreadConstraints. The 7th item in requirements is the operator controller (not a scale set) and is correctly excluded. topologyKey: kubernetes.io/hostname confirmed in all 6. |
| RNRS-02 | 02-01-PLAN | Runner scale sets have nodeSelector pinning runners to nodes labeled `role=runners` | SATISFIED (label key correction applied) | All 6 runner scale sets have nodeSelector. Phase 1 locked the actual label key as `node-role` (not `role`). REQUIREMENTS.md contains a documentation error; implementation correctly uses `node-role: runners`. |
| SCHED-01 | 02-02-PLAN, 02-03-PLAN, 02-04-PLAN | Stateful workloads (databases, Forgejo, Harbor) have nodeAffinity targeting appropriate node roles | SATISFIED | forgejo-db → apps, keycloak-db → infra (nodeAffinityPreset hard). Forgejo app → apps, Keycloak app → infra (nodeSelector). Harbor all components → apps (8 per-component nodeSelectors). |
| SCHED-02 | 02-02-PLAN | PostgreSQL instances have pod anti-affinity to prevent co-location on same node | SATISFIED | Both postgres HelmReleases have `podAntiAffinityPreset: hard`. At replica=1 this has no active effect but correctly encodes intent and will enforce separation if replicas scale. |
| SCHED-03 | 02-03-PLAN, 02-04-PLAN | Application pods have topologySpreadConstraints to spread across nodes | SATISFIED (with documented partial scope) | Forgejo app has topologySpreadConstraints (kubernetes.io/hostname, ScheduleAnyway). Harbor components and Keycloak intentionally omit topology spread — all Harbor components and Keycloak run at replica=1, making topology spread a no-op. This is a correct engineering decision documented in the plans. |

**Orphaned requirements check:** REQUIREMENTS.md maps RNRS-01, RNRS-02, SCHED-01, SCHED-02, SCHED-03 to Phase 2 — exactly the set claimed by the four plans. No orphaned requirements.

---

### Anti-Patterns Found

No anti-patterns found.

Scanned all 11 modified files. No TODOs, FIXMEs, placeholder comments, empty implementations, or stub patterns found. All files contain complete, substantive YAML configuration.

Specific checks:
- No bare `role:` label key (would be wrong) — confirmed absent in all files
- No `primary.affinity` block in either postgres file (would silence nodeAffinityPreset) — confirmed absent
- No `affinity:` override in keycloak/helmrelease.yaml (would replace chart's default podAntiAffinity) — confirmed absent
- Harbor `node-role: apps` count = 8 exactly — matches 8 expected component sections

---

### Human Verification Required

#### 1. Node Labels Not Yet Applied

**Test:** After Phase 1 (node labeling) applies labels to cluster nodes, verify that runner pods land on nodes with `node-role=runners`, Forgejo/Harbor land on `node-role=apps`, and Keycloak lands on `node-role=infra`.
**Expected:** `kubectl get pods -o wide` shows each workload's pod on the correct node type.
**Why human:** Node labels are applied imperatively to the cluster — this is a Phase 1 prerequisite that is not yet complete. The GitOps configuration is correct, but runtime scheduling behavior cannot be verified without the labels on live nodes.

#### 2. Topology Spread Runtime Behavior (Runners)

**Test:** Scale a runner set to 3+ replicas and verify pods land on distinct nodes.
**Expected:** Each runner pod scheduled on a different node hostname (or best-effort spread when fewer nodes than pods).
**Why human:** Topology spread constraints can only be tested with multiple live pod instances across multiple nodes.

#### 3. Bitnami nodeAffinityPreset Rendering

**Test:** After deploying forgejo-db and keycloak-db, inspect the rendered Pod spec: `kubectl get pod -n forgejo -l app.kubernetes.io/name=postgresql -o yaml | grep -A 20 affinity`
**Expected:** The pod spec contains a `requiredDuringSchedulingIgnoredDuringExecution` nodeAffinity rule matching `node-role In [apps]` (for forgejo-db) and `node-role In [infra]` (for keycloak-db).
**Why human:** The Bitnami chart renders the preset into a full affinity block; the rendered output can only be inspected at deploy time, not from the HelmRelease YAML alone.

---

### Summary

Phase 2 goal is **fully achieved** in the GitOps configuration layer. All 6 ARC runner scale sets have nodeSelector (`node-role: runners`) and topologySpreadConstraints (`kubernetes.io/hostname`, `ScheduleAnyway`). All stateful workloads have node affinity: forgejo-db → apps, keycloak-db → infra (via Bitnami nodeAffinityPreset hard), Forgejo app → apps (nodeSelector + topologySpreadConstraints), Keycloak app → infra (nodeSelector), Harbor all 8 components → apps (per-component nodeSelector). PostgreSQL instances declare podAntiAffinityPreset: hard. The label key is consistently `node-role` across all files.

Two items are correct engineering decisions that deviate from literal requirement wording:

1. **6 runner sets, not 7** — the 7th HelmRelease in the ARC directory is the controller operator, not a scale set. All 6 actual runner scale sets are constrained.
2. **REQUIREMENTS.md says `role=runners`** — the actual label key is `node-role`, established in Phase 1. The requirements document contains a documentation error; the implementation is correct.

Runtime verification requires Phase 1 node labels to be applied to the cluster (documented pre-existing blocker). All automated checks pass.

---

_Verified: 2026-02-28_
_Verifier: Claude (gsd-verifier)_
