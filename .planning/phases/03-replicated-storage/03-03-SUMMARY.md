---
phase: 03-replicated-storage
plan: "03"
subsystem: infra
tags: [longhorn, storage, kubernetes, helm, harbor, keycloak, postgresql]

# Dependency graph
requires:
  - phase: 03-replicated-storage-01
    provides: longhorn-replicated StorageClass created in Longhorn
provides:
  - Keycloak PostgreSQL primary PVC switched to longhorn-replicated (STOR-04)
  - Harbor internal database PVC switched to longhorn-replicated (STOR-05)
affects: [03-replicated-storage, scheduling-constraints, keycloak, harbor]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Targeted storageClass override per PVC — only critical database PVCs use replicated storage, not bulk storage PVCs

key-files:
  created: []
  modified:
    - clusters/k3s-cluster/apps/keycloak/postgres-helmrelease.yaml
    - clusters/k3s-cluster/apps/harbor/helmrelease.yaml

key-decisions:
  - "Only the database PVC uses longhorn-replicated for Harbor — registry (200Gi), jobservice, and trivy remain on default longhorn to balance fault-tolerance with storage efficiency"
  - "Harbor database is bundled inside the main harbor HelmRelease (not a separate PostgreSQL HelmRelease) — storageClass set under persistence.persistentVolumeClaim.database"

patterns-established:
  - "Selective replication pattern: opt-in replicated storage per PVC using explicit storageClass field, not a cluster-wide default change"

requirements-completed:
  - STOR-04
  - STOR-05

# Metrics
duration: 5min
completed: 2026-02-28
---

# Phase 3 Plan 03: Replicated Storage — Keycloak & Harbor Database PVCs Summary

**Keycloak PostgreSQL and Harbor internal database PVCs switched to longhorn-replicated StorageClass, protecting critical identity and registry metadata from node failures while leaving bulk storage (registry 200Gi, jobservice, trivy) on default longhorn**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-02-28T15:22:00Z
- **Completed:** 2026-02-28T15:27:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Keycloak PostgreSQL primary.persistence.storageClass changed from `longhorn` to `longhorn-replicated` (STOR-04)
- Harbor internal database persistence.persistentVolumeClaim.database.storageClass changed from `longhorn` to `longhorn-replicated` (STOR-05)
- Harbor registry (200Gi), jobservice (1Gi), and trivy (5Gi) PVCs left unchanged on default `longhorn`

## Task Commits

Each task was committed atomically:

1. **Task 1: Update Keycloak PostgreSQL primary storageClass to longhorn-replicated** - `27a5ec6` (feat)
2. **Task 2: Update Harbor internal database storageClass to longhorn-replicated** - `a69ac88` (feat)

## Files Created/Modified
- `clusters/k3s-cluster/apps/keycloak/postgres-helmrelease.yaml` - primary.persistence.storageClass: longhorn-replicated
- `clusters/k3s-cluster/apps/harbor/helmrelease.yaml` - persistence.persistentVolumeClaim.database.storageClass: longhorn-replicated

## Decisions Made
- Only the database PVC in Harbor uses longhorn-replicated; registry/jobservice/trivy remain on default longhorn. Replicating 200Gi registry storage would be expensive and unnecessary — the registry content can be re-pushed, but database loss requires full reconfiguration.
- Harbor's database is bundled in the main harbor HelmRelease (not a separate HelmRelease). The storageClass is set under `persistence.persistentVolumeClaim.database.storageClass`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required. Longhorn-replicated StorageClass was created in Phase 03-01. These HelmRelease changes will be applied by Flux when committed to the repo.

## Next Phase Readiness
- STOR-04 and STOR-05 are complete — Keycloak and Harbor databases will use replicated storage on next Flux reconciliation
- Remaining replicated storage tasks (Forgejo PostgreSQL) should be addressed in subsequent plans if scoped
- No blockers for continuing with other Phase 3 plans

---
*Phase: 03-replicated-storage*
*Completed: 2026-02-28*
