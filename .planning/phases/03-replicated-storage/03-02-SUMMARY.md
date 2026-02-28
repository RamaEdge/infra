---
phase: 03-replicated-storage
plan: "02"
subsystem: infra
tags: [longhorn, storage, forgejo, postgresql, kubernetes, helm, flux]

# Dependency graph
requires:
  - phase: 03-01
    provides: longhorn-replicated StorageClass defined and available in cluster

provides:
  - Forgejo app data PVC (200Gi) configured to use longhorn-replicated StorageClass
  - Forgejo PostgreSQL primary PVC (1Gi) configured to use longhorn-replicated StorageClass

affects:
  - 03-replicated-storage subsequent plans

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Explicit StorageClass opt-in: workloads explicitly reference longhorn-replicated instead of default longhorn"

key-files:
  created: []
  modified:
    - clusters/k3s-cluster/apps/forgejo/helmrelease.yaml
    - clusters/k3s-cluster/apps/forgejo/postgres-helmrelease.yaml

key-decisions:
  - "Changed only storageClass field in each HelmRelease — no other content modified"
  - "postgres-helmrelease uses primary.persistence.storageClass (Bitnami chart path), not top-level persistence.storageClass"

patterns-established:
  - "StorageClass change pattern: single field update, surrounding persistence block unchanged"

requirements-completed: [STOR-02, STOR-03]

# Metrics
duration: 5min
completed: 2026-02-28
---

# Phase 03 Plan 02: Forgejo Replicated Storage Summary

**Forgejo app data (200Gi) and PostgreSQL primary (1Gi) PVCs switched from longhorn to longhorn-replicated, ensuring git repository data survives a single-node failure**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-02-28T15:20:00Z
- **Completed:** 2026-02-28T15:25:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Updated `clusters/k3s-cluster/apps/forgejo/helmrelease.yaml` persistence.storageClass from `longhorn` to `longhorn-replicated` (200Gi app data volume — STOR-02)
- Updated `clusters/k3s-cluster/apps/forgejo/postgres-helmrelease.yaml` primary.persistence.storageClass from `longhorn` to `longhorn-replicated` (1Gi database volume — STOR-03)
- No other content changed in either file; all surrounding configuration preserved

## Task Commits

Each task was committed atomically:

1. **Task 1: Update Forgejo app data storageClass to longhorn-replicated** - `9e2d4e7` (feat)
2. **Task 2: Update Forgejo PostgreSQL primary storageClass to longhorn-replicated** - `b8c726a` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `clusters/k3s-cluster/apps/forgejo/helmrelease.yaml` - Changed persistence.storageClass: longhorn -> longhorn-replicated (line 41)
- `clusters/k3s-cluster/apps/forgejo/postgres-helmrelease.yaml` - Changed primary.persistence.storageClass: longhorn -> longhorn-replicated (line 45)

## Decisions Made

None - followed plan as specified. The plan explicitly documented the correct Bitnami chart path (`primary.persistence.storageClass`) to use for the PostgreSQL HelmRelease.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required. Changes will be applied automatically by Flux on next reconciliation. Note that changing storageClass on existing PVCs requires manual PVC migration (existing PVCs cannot be resized to a different StorageClass); these changes apply to fresh deployments or manual PVC recreation.

## Next Phase Readiness

- Forgejo HelmReleases now reference longhorn-replicated for both app data and database storage
- Ready for subsequent 03-replicated-storage plans covering other services
- For existing deployments: PVC migration must be performed manually before the new StorageClass takes effect on running pods

---
*Phase: 03-replicated-storage*
*Completed: 2026-02-28*
