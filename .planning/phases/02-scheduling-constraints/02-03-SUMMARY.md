---
phase: 02-scheduling-constraints
plan: "03"
subsystem: infra
tags: [kubernetes, scheduling, nodeSelector, topologySpreadConstraints, forgejo, keycloak, helmrelease]

# Dependency graph
requires:
  - phase: 02-scheduling-constraints
    provides: Research on chart-level scheduling fields and node roles for infra workloads
provides:
  - Forgejo app pods pinned to node-role=apps via nodeSelector
  - Forgejo app pods spread across nodes via topologySpreadConstraints
  - Keycloak app pods pinned to node-role=infra via nodeSelector
affects:
  - 02-scheduling-constraints (remaining plans that add nodeSelector to other apps)
  - Phase 1 node labeling (labels must exist on cluster nodes for these selectors to function)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - nodeSelector with node-role label key for pod-to-node affinity in HelmRelease values
    - topologySpreadConstraints with ScheduleAnyway for single-replica app spread (low-risk)
    - Avoid keycloakx affinity override to preserve chart's default podAntiAffinity template

key-files:
  created: []
  modified:
    - clusters/k3s-cluster/apps/forgejo/helmrelease.yaml
    - clusters/k3s-cluster/apps/keycloak/helmrelease.yaml

key-decisions:
  - "Use ScheduleAnyway (not DoNotSchedule) for Forgejo topologySpreadConstraints — single-replica pod; hard constraint risks unschedulability on imbalanced apps nodes"
  - "Keycloak: nodeSelector only, no affinity override — keycloakx chart renders affinity via tpl (Go template string); overriding it replaces the default podAntiAffinity which must be preserved"
  - "Keycloak: no topologySpreadConstraints — single-replica deployment; topology spread adds no scheduling benefit for a single pod"
  - "Label key is node-role (not role) — consistent with cluster node label scheme established in Phase 1"

patterns-established:
  - "HelmRelease nodeSelector pattern: add nodeSelector at top-level of values block, before other keys"
  - "topologySpreadConstraints for multi-tenant apps: maxSkew=1, topologyKey=kubernetes.io/hostname, ScheduleAnyway for resilient single-replica workloads"
  - "Chart-specific research before adding scheduling constraints: keycloakx affinity is tpl-rendered and must not be overridden"

requirements-completed: [SCHED-01, SCHED-03]

# Metrics
duration: 1min
completed: 2026-02-28
---

# Phase 02 Plan 03: Forgejo and Keycloak App Node Pinning Summary

**Forgejo pinned to node-role=apps with hostname-spread topologySpreadConstraints; Keycloak pinned to node-role=infra with nodeSelector only, preserving chart's default podAntiAffinity**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-02-28T15:12:28Z
- **Completed:** 2026-02-28T15:13:07Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Forgejo HelmRelease updated with `nodeSelector: {node-role: apps}` and `topologySpreadConstraints` targeting `kubernetes.io/hostname` with `ScheduleAnyway`
- Keycloak HelmRelease updated with `nodeSelector: {node-role: infra}` only — intentionally omitting affinity override to preserve chart default
- All existing values in both files preserved unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Add nodeSelector and topologySpreadConstraints to Forgejo app HelmRelease** - `0ad3948` (feat)
2. **Task 2: Add nodeSelector to Keycloak app HelmRelease** - `2122269` (feat)

**Plan metadata:** (docs commit, see final commit)

## Files Created/Modified
- `clusters/k3s-cluster/apps/forgejo/helmrelease.yaml` - Added nodeSelector (node-role: apps) and topologySpreadConstraints at top of values block
- `clusters/k3s-cluster/apps/keycloak/helmrelease.yaml` - Added nodeSelector (node-role: infra) at top of values block

## Decisions Made

1. **Forgejo topologySpreadConstraints uses ScheduleAnyway** — Forgejo is a single-replica deployment. Using `DoNotSchedule` would risk the pod becoming unschedulable if apps nodes have any spread imbalance. `ScheduleAnyway` enforces best-effort spread without blocking scheduling.

2. **Keycloak uses nodeSelector only — no affinity override** — The keycloakx chart (codecentric/keycloakx 7.1.5) renders `affinity` as a Go template string via the `tpl` function. Providing a custom affinity value replaces (not merges with) the chart's built-in `podAntiAffinity`. Since the default affinity is correct and desired, we intentionally leave it untouched. `nodeSelector` alone achieves SCHED-01 node role pinning.

3. **No topologySpreadConstraints for Keycloak** — Keycloak runs as a single replica. Topology spread constraints are meaningless for a single pod and would add complexity with no scheduling benefit.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Both Forgejo and Keycloak app pods will schedule on correct node roles once node labels are applied on the cluster (Phase 1 prerequisite)
- Forgejo will spread across apps nodes via topologySpreadConstraints when multiple apps nodes are available
- Phase 2 remaining plans can continue pinning other workloads (PostgreSQL instances, etc.)
- Node labels must be applied imperatively on the cluster before these scheduling constraints take effect

---
*Phase: 02-scheduling-constraints*
*Completed: 2026-02-28*
