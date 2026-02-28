---
phase: 02-scheduling-constraints
plan: 02
subsystem: infra
tags: [kubernetes, node-affinity, scheduling, postgresql, bitnami, helmrelease]

# Dependency graph
requires:
  - phase: 02-scheduling-constraints
    provides: Research on Bitnami PostgreSQL chart nodeAffinityPreset and podAntiAffinityPreset fields
provides:
  - forgejo-db pinned to nodes with label node-role=apps via hard nodeAffinityPreset
  - keycloak-db pinned to nodes with label node-role=infra via hard nodeAffinityPreset
  - Both PostgreSQL HelmReleases declare podAntiAffinityPreset: hard to prevent co-location
affects: [node-labeling, forgejo, keycloak, postgresql]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bitnami chart nodeAffinityPreset pattern: use primary.nodeAffinityPreset.type/key/values instead of primary.affinity (preset is silently ignored when affinity is also set)"
    - "podAntiAffinityPreset: hard documents co-location prevention intent even at replica=1"

key-files:
  created: []
  modified:
    - clusters/k3s-cluster/apps/forgejo/postgres-helmrelease.yaml
    - clusters/k3s-cluster/apps/keycloak/postgres-helmrelease.yaml

key-decisions:
  - "Used nodeAffinityPreset (preset) approach instead of raw affinity block — less YAML, same result, and avoids the silent-ignore conflict when both are set"
  - "forgejo-db targets apps node role — Forgejo is a developer-facing app service"
  - "keycloak-db targets infra node role — Keycloak is SSO infrastructure"
  - "podAntiAffinityPreset: hard set on both even at replica=1 — no scheduling effect now but correctly documents intent and enforces separation if replicas scale"

patterns-established:
  - "Bitnami preset pattern: primary.nodeAffinityPreset.type/key/values for node pinning, never combine with primary.affinity"
  - "Node role label key is node-role (not role) — consistent across all scheduling constraints in this phase"

requirements-completed:
  - SCHED-01
  - SCHED-02

# Metrics
duration: 3min
completed: 2026-02-28
---

# Phase 02 Plan 02: Scheduling Constraints Summary

**Hard nodeAffinityPreset added to both PostgreSQL HelmReleases pinning forgejo-db to apps nodes and keycloak-db to infra nodes using Bitnami chart preset fields**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-28T08:52:23Z
- **Completed:** 2026-02-28T08:55:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- forgejo/postgres-helmrelease.yaml: primary block now includes nodeAffinityPreset (type: hard, key: node-role, values: [apps]) and podAntiAffinityPreset: hard
- keycloak/postgres-helmrelease.yaml: primary block now includes nodeAffinityPreset (type: hard, key: node-role, values: [infra]) and podAntiAffinityPreset: hard
- No existing fields were removed or altered — fullnameOverride, global.postgresql.auth, persistence, and resources all preserved
- Neither file has a primary.affinity block — presets will be honoured by the Bitnami chart

## Task Commits

Each task was committed atomically:

1. **Task 1: Add nodeAffinityPreset and podAntiAffinityPreset to forgejo-db** - `2920400` (feat)
2. **Task 2: Add nodeAffinityPreset and podAntiAffinityPreset to keycloak-db** - `2c2d6ce` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `clusters/k3s-cluster/apps/forgejo/postgres-helmrelease.yaml` - Added nodeAffinityPreset (apps) and podAntiAffinityPreset: hard to primary block
- `clusters/k3s-cluster/apps/keycloak/postgres-helmrelease.yaml` - Added nodeAffinityPreset (infra) and podAntiAffinityPreset: hard to primary block

## Decisions Made
- Used the Bitnami preset approach (primary.nodeAffinityPreset) rather than a raw primary.affinity block. The Bitnami chart silently ignores presets when a custom affinity block is also set, so using presets alone is the safe approach.
- forgejo-db targets apps because Forgejo is a developer-facing application service (consistent with Phase 1 node role decisions).
- keycloak-db targets infra because Keycloak is SSO infrastructure (consistent with Phase 1 node role decisions).
- podAntiAffinityPreset: hard is set on both HelmReleases. At replica=1 this has no active scheduling effect, but it correctly documents intent to prevent co-location if replicas scale beyond 1.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

Note: Node labels (node-role=apps, node-role=infra) must be applied imperatively on the cluster before these affinity rules take scheduling effect. The HelmReleases are syntactically valid without the labels but the PostgreSQL pods will remain pending if labels are absent.

## Next Phase Readiness
- Both PostgreSQL scheduling constraints are in place
- Phase 2 Plan 02 is complete: SCHED-01 and SCHED-02 satisfied
- Remaining work in phase 02: any additional scheduling constraints for other workloads
- Phase 3 can proceed in parallel

---
*Phase: 02-scheduling-constraints*
*Completed: 2026-02-28*
