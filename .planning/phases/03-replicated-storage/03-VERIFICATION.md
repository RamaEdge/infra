---
phase: 03-replicated-storage
verified: 2026-02-28T16:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
human_verification:
  - test: "Confirm longhorn-replicated StorageClass exists in infra-core at /Users/ravichillerega/sources/core/infra-core"
    expected: "clusters/k3s-cluster/apps/longhorn/storageclasses.yaml contains longhorn-replicated with numberOfReplicas: \"2\" and provisioner: driver.longhorn.io"
    why_human: "Plan 03-01 targets infra-core repo (manual: true, target_repo: infra-core). Cannot verify cross-repo artifacts from this verification session."
---

# Phase 3: Replicated Storage Verification Report

**Phase Goal:** Critical stateful data is stored on replicated Longhorn volumes that survive a single-node failure
**Verified:** 2026-02-28T16:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Scope Note: Plan 03-01 (STOR-01)

Plan 03-01 is marked `manual: true` and `target_repo: infra-core`. It targets `/Users/ravichillerega/sources/core/infra-core`, not this repo. The longhorn-replicated StorageClass is created manually by the operator in infra-core. STOR-01 is **deferred to infra-core** and is not a gap in this repo. The 03-04 SUMMARY confirms the executor verified the StorageClass exists in infra-core (`apps/longhorn/storageclasses.yaml`). A human verification item is noted below for independent confirmation.

Plans 03-02, 03-03, and 03-04 (STOR-02 through STOR-06) are fully verified against this codebase below.

---

## Goal Achievement

### Success Criteria from ROADMAP.md

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| 1 | A `longhorn-replicated` StorageClass exists with replica count 2 or higher | DEFERRED (infra-core) | Documented in 03-04 SUMMARY; see human verification |
| 2 | Forgejo app data PVC (200Gi) uses longhorn-replicated | VERIFIED | `clusters/k3s-cluster/apps/forgejo/helmrelease.yaml` line 41: `storageClass: longhorn-replicated` |
| 3 | All four PostgreSQL PVCs (Forgejo, Keycloak, Harbor, Smedja) use longhorn-replicated | VERIFIED | See artifact table — all four confirmed |
| 4 | Default StorageClass remains unchanged — non-critical workloads are unaffected | VERIFIED | Harbor registry/jobservice/trivy remain `storageClass: longhorn`; no is-default-class annotation added to longhorn-replicated |

### Observable Truths (from plan must_haves)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Forgejo app data PVC (200Gi) is configured to use longhorn-replicated | VERIFIED | `helmrelease.yaml` line 41 |
| 2 | Forgejo PostgreSQL primary PVC (1Gi) is configured to use longhorn-replicated | VERIFIED | `postgres-helmrelease.yaml` line 45 |
| 3 | Keycloak PostgreSQL primary PVC (1Gi) is configured to use longhorn-replicated | VERIFIED | `keycloak/postgres-helmrelease.yaml` line 45 |
| 4 | Harbor internal database PVC (1Gi) is configured to use longhorn-replicated | VERIFIED | `harbor/helmrelease.yaml` line 139 |
| 5 | Harbor registry, jobservice, and trivy PVCs remain on longhorn (unchanged) | VERIFIED | Lines 123, 130, 135 show `storageClass: longhorn` |
| 6 | A smedja namespace manifest exists in apps/smedja/ | VERIFIED | File exists with `name: smedja` |
| 7 | A Smedja PostgreSQL HelmRelease exists with primary PVC size 10Gi on longhorn-replicated | VERIFIED | `smedja/postgres-helmrelease.yaml` lines 38-39 |
| 8 | The Smedja app directory is registered in the top-level cluster kustomization | VERIFIED | `clusters/k3s-cluster/kustomization.yaml` line 14: `- apps/smedja` |
| 9 | No other fields in modified HelmReleases were changed (surgical edits only) | VERIFIED | All surrounding config (sizes, enabled flags, auth, resources) intact |

**Score:** 9/9 truths verified (STOR-01 deferred to infra-core per prompt instructions)

---

## Required Artifacts

### Plan 03-01 (STOR-01 — deferred to infra-core)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `clusters/k3s-cluster/apps/longhorn-config/storageclass-replicated.yaml` | longhorn-replicated StorageClass manifest | DEFERRED (infra-core) | Plan targets infra-core repo; not expected in this repo |
| `clusters/k3s-cluster/apps/longhorn-config/kustomization.yaml` | Flux Kustomization registering StorageClass | DEFERRED (infra-core) | Plan targets infra-core repo; not expected in this repo |
| `clusters/k3s-cluster/kustomization.yaml` | Top-level cluster resource list | NOTE | `apps/longhorn-config` is correctly absent — it lives in infra-core |

### Plan 03-02 (STOR-02, STOR-03)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `clusters/k3s-cluster/apps/forgejo/helmrelease.yaml` | Forgejo app HelmRelease with storageClass: longhorn-replicated | VERIFIED | Line 41: `storageClass: longhorn-replicated`, size 200Gi intact, no other changes |
| `clusters/k3s-cluster/apps/forgejo/postgres-helmrelease.yaml` | Forgejo PostgreSQL HelmRelease with storageClass: longhorn-replicated | VERIFIED | Line 45: `storageClass: longhorn-replicated` under `primary.persistence`, size 1Gi intact |

### Plan 03-03 (STOR-04, STOR-05)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `clusters/k3s-cluster/apps/keycloak/postgres-helmrelease.yaml` | Keycloak PostgreSQL HelmRelease with storageClass: longhorn-replicated | VERIFIED | Line 45: `storageClass: longhorn-replicated` under `primary.persistence`, size 1Gi intact |
| `clusters/k3s-cluster/apps/harbor/helmrelease.yaml` | Harbor HelmRelease with database storageClass: longhorn-replicated | VERIFIED | Line 139: `storageClass: longhorn-replicated` under `database:` block; registry/jobservice/trivy retain `storageClass: longhorn` |

### Plan 03-04 (STOR-06)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `clusters/k3s-cluster/apps/smedja/namespace.yaml` | smedja Namespace manifest | VERIFIED | `kind: Namespace`, `name: smedja` |
| `clusters/k3s-cluster/apps/smedja/postgres-helmrelease.yaml` | Smedja PostgreSQL HelmRelease | VERIFIED | name: smedja-db, bitnami/postgresql 18.1.13, storageClass: longhorn-replicated, size: 10Gi, existingSecret: smedja-db-credentials |
| `clusters/k3s-cluster/apps/smedja/kustomization.yaml` | Smedja Flux Kustomization | VERIFIED | Lists `namespace.yaml` and `postgres-helmrelease.yaml` |
| `clusters/k3s-cluster/kustomization.yaml` | Top-level cluster resource list | VERIFIED | Line 14: `- apps/smedja` present; all prior entries intact |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `forgejo/helmrelease.yaml` | longhorn-replicated StorageClass | `persistence.storageClass` value | WIRED | Line 41 exactly matches `storageClass: longhorn-replicated` |
| `forgejo/postgres-helmrelease.yaml` | longhorn-replicated StorageClass | `primary.persistence.storageClass` value | WIRED | Line 45 exactly matches `storageClass: longhorn-replicated` |
| `keycloak/postgres-helmrelease.yaml` | longhorn-replicated StorageClass | `primary.persistence.storageClass` value | WIRED | Line 45 exactly matches `storageClass: longhorn-replicated` |
| `harbor/helmrelease.yaml` | longhorn-replicated StorageClass | `persistence.persistentVolumeClaim.database.storageClass` | WIRED | Line 139: `storageClass: longhorn-replicated` under `database:` block only |
| `clusters/k3s-cluster/kustomization.yaml` | `apps/smedja/kustomization.yaml` | resources entry | WIRED | `- apps/smedja` present in top-level kustomization |
| `smedja/postgres-helmrelease.yaml` | longhorn-replicated StorageClass | `primary.persistence.storageClass` value | WIRED | Line 38: `storageClass: longhorn-replicated` |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| STOR-01 | 03-01 | longhorn-replicated StorageClass defined with replica count 2+ | DEFERRED (infra-core) | manual: true, targets infra-core repo; executor confirmed StorageClass exists in infra-core |
| STOR-02 | 03-02 | Forgejo app data PVC (200Gi) uses longhorn-replicated | SATISFIED | `forgejo/helmrelease.yaml` line 41 |
| STOR-03 | 03-02 | Forgejo PostgreSQL PVC (1Gi) uses longhorn-replicated | SATISFIED | `forgejo/postgres-helmrelease.yaml` line 45 |
| STOR-04 | 03-03 | Keycloak PostgreSQL PVC (1Gi) uses longhorn-replicated | SATISFIED | `keycloak/postgres-helmrelease.yaml` line 45 |
| STOR-05 | 03-03 | Harbor PostgreSQL PVC (1Gi) uses longhorn-replicated | SATISFIED | `harbor/helmrelease.yaml` line 139 (database PVC only) |
| STOR-06 | 03-04 | Smedja PostgreSQL PVC (10Gi) uses longhorn-replicated | SATISFIED | `smedja/postgres-helmrelease.yaml` lines 38-39 |

No orphaned requirements: all six STOR requirements from the prompt are accounted for in plan frontmatter.

---

## Anti-Patterns Found

No anti-patterns detected. Scanning files modified across plans 03-02, 03-03, 03-04:

| File | Pattern Scanned | Result |
|------|-----------------|--------|
| `forgejo/helmrelease.yaml` | TODO/FIXME, placeholder, return null, empty handlers | None found |
| `forgejo/postgres-helmrelease.yaml` | TODO/FIXME, placeholder, return null, empty handlers | None found |
| `keycloak/postgres-helmrelease.yaml` | TODO/FIXME, placeholder, return null, empty handlers | None found |
| `harbor/helmrelease.yaml` | TODO/FIXME, placeholder, return null, empty handlers | None found |
| `smedja/namespace.yaml` | TODO/FIXME, placeholder | None found |
| `smedja/postgres-helmrelease.yaml` | TODO/FIXME, placeholder, return null | None found |
| `smedja/kustomization.yaml` | TODO/FIXME, placeholder | None found |
| `clusters/k3s-cluster/kustomization.yaml` | TODO/FIXME, placeholder | None found |

One expected operational condition noted (not an anti-pattern): `smedja-db-credentials` Secret must be created imperatively on the cluster before `smedja-db` HelmRelease reconciles. This matches the established pattern for other databases (forgejo-db, keycloak-db) and is documented in the SUMMARY.

---

## Human Verification Required

### 1. Confirm longhorn-replicated StorageClass in infra-core

**Test:** In the infra-core repo at `/Users/ravichillerega/sources/core/infra-core`, open `clusters/k3s-cluster/apps/longhorn/storageclasses.yaml` (or equivalent path documented in plan 03-01). Verify it contains:
- `name: longhorn-replicated`
- `provisioner: driver.longhorn.io`
- `numberOfReplicas: "2"` (as a quoted string, not integer)
- No `storageclass.kubernetes.io/is-default-class` annotation

**Expected:** File exists with all four conditions true, confirming the StorageClass foundation that STOR-02 through STOR-06 all depend on.

**Why human:** Plan 03-01 targets a different repository (`infra-core`) with `manual: true`. This verification session cannot read across repo boundaries with confidence. The executor's SUMMARY (plan 03-04) states it confirmed this, but an independent check closes the loop on STOR-01.

---

## Gaps Summary

No gaps. All plans executed correctly in this repo:

- **Plan 03-02 (STOR-02, STOR-03):** Both Forgejo HelmReleases have been surgically updated to `longhorn-replicated`. Surrounding configuration (sizes, auth, ingress, resources) is intact.
- **Plan 03-03 (STOR-04, STOR-05):** Keycloak PostgreSQL and Harbor database PVCs updated to `longhorn-replicated`. Harbor's three non-database PVCs (registry 200Gi, jobservice 1Gi, trivy 5Gi) correctly remain on `longhorn`. The targeted edit is precise.
- **Plan 03-04 (STOR-06):** Smedja directory created with namespace, PostgreSQL HelmRelease (bitnami/postgresql 18.1.13, longhorn-replicated, 10Gi, existingSecret pattern), and kustomization. Registered in top-level cluster kustomization.
- **Plan 03-01 (STOR-01):** Correctly deferred to infra-core. The absence of `apps/longhorn-config` from this repo's kustomization is expected and correct.

The phase goal is achieved for all work scoped to this repo. STOR-01 depends on infra-core and is flagged for human confirmation only.

---

_Verified: 2026-02-28T16:00:00Z_
_Verifier: Claude (gsd-verifier)_
