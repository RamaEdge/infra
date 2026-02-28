---
phase: 03-replicated-storage
plan: "04"
subsystem: infra
tags: [kubernetes, flux, postgresql, longhorn, bitnami, helm, smedja]

# Dependency graph
requires:
  - phase: 03-01
    provides: longhorn-replicated StorageClass on cluster (STOR-01)
provides:
  - apps/smedja namespace manifest
  - smedja-db PostgreSQL HelmRelease (bitnami/postgresql 18.1.13, longhorn-replicated, 10Gi)
  - apps/smedja kustomization registered in top-level cluster kustomization
affects: [smedja-future-deployment, stor-06-requirement]

# Tech tracking
tech-stack:
  added: []
  patterns: [bitnami-postgresql-helmrelease, longhorn-replicated-pvc, flux-app-directory-structure]

key-files:
  created:
    - clusters/k3s-cluster/apps/smedja/namespace.yaml
    - clusters/k3s-cluster/apps/smedja/postgres-helmrelease.yaml
    - clusters/k3s-cluster/apps/smedja/kustomization.yaml
  modified:
    - clusters/k3s-cluster/kustomization.yaml

key-decisions:
  - "HelmRelease uses existingSecret: smedja-db-credentials — secret must be created imperatively on cluster before HelmRelease will reconcile successfully"
  - "kustomization.yaml omits helmrelease.yaml (Smedja app not yet deployed) — only namespace and postgres HelmRelease registered"
  - "apps/longhorn-config not present in infra repo kustomization — longhorn-replicated StorageClass is managed in infra-core repo (plan 03-01)"

patterns-established:
  - "Smedja app directory follows same pattern as forgejo: namespace.yaml + postgres-helmrelease.yaml + kustomization.yaml"
  - "PostgreSQL HelmRelease targets longhorn-replicated StorageClass at 10Gi — explicit opt-in for replicated storage"

requirements-completed: [STOR-06]

# Metrics
duration: 1min
completed: 2026-02-28
---

# Phase 03 Plan 04: Smedja PostgreSQL Infrastructure Summary

**Smedja namespace and 10Gi replicated PostgreSQL HelmRelease (bitnami/postgresql 18.1.13) registered in cluster Flux kustomization, satisfying STOR-06**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-28T15:30:06Z
- **Completed:** 2026-02-28T15:30:55Z
- **Tasks:** 2
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments
- Created `apps/smedja/` directory with namespace, PostgreSQL HelmRelease, and kustomization
- Configured smedja-db HelmRelease using bitnami/postgresql 18.1.13 with longhorn-replicated StorageClass at 10Gi (STOR-06)
- Registered `apps/smedja` in top-level cluster kustomization to enable Flux reconciliation

## Task Commits

Each task was committed atomically:

1. **Task 1: Create apps/smedja directory with namespace, PostgreSQL HelmRelease, and kustomization** - `d0372fe` (feat)
2. **Task 2: Register apps/smedja in the top-level cluster kustomization** - `9a4920f` (feat)

## Files Created/Modified
- `clusters/k3s-cluster/apps/smedja/namespace.yaml` - Smedja namespace definition
- `clusters/k3s-cluster/apps/smedja/postgres-helmrelease.yaml` - smedja-db HelmRelease: bitnami/postgresql 18.1.13, longhorn-replicated, 10Gi, existingSecret: smedja-db-credentials
- `clusters/k3s-cluster/apps/smedja/kustomization.yaml` - Flux kustomization registering namespace and postgres HelmRelease
- `clusters/k3s-cluster/kustomization.yaml` - Added `- apps/smedja` entry after `apps/forgejo`

## Decisions Made
- `kustomization.yaml` lists only `namespace.yaml` and `postgres-helmrelease.yaml` (no `helmrelease.yaml`) since Smedja app is not yet deployed — follows the plan's intent explicitly
- `existingSecret: smedja-db-credentials` will need to be created imperatively on cluster before HelmRelease reconciles successfully — this matches the expected pattern used by other databases in the repo
- `apps/longhorn-config` is NOT present in the infra repo kustomization — the `longhorn-replicated` StorageClass is managed in the `infra-core` repo under `apps/longhorn/storageclasses.yaml` (already contains longhorn-replicated definition)

## Deviations from Plan

The plan context showed `apps/longhorn-config` in the top-level kustomization (described as "added by plan 03-01"), but plan 03-01 targets the `infra-core` repo, not this `infra` repo. The `longhorn-replicated` StorageClass is already defined in `infra-core/clusters/k3s-cluster/apps/longhorn/storageclasses.yaml`. No `apps/longhorn-config` exists or needs to exist in this repo's kustomization.

None - plan executed exactly as written for the infra repo scope.

## Issues Encountered
None.

## User Setup Required
Before the smedja-db HelmRelease will reconcile successfully, the `smedja-db-credentials` Secret must be created imperatively on the cluster in the `smedja` namespace with keys `postgres-password` and `password`. This is expected behavior matching other databases in the repo.

## Next Phase Readiness
- STOR-06 satisfied: Smedja PostgreSQL PVC (10Gi) configured to use longhorn-replicated StorageClass
- Smedja infrastructure foundation complete — ready for future full Smedja application deployment
- No blockers for remaining phase 03 plans

---
*Phase: 03-replicated-storage*
*Completed: 2026-02-28*
