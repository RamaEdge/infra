---
phase: 02-scheduling-constraints
plan: "04"
subsystem: infra
tags: [harbor, kubernetes, scheduling, nodeSelector, helm]

# Dependency graph
requires: []
provides:
  - Harbor all 8 component pods pinned to apps nodes via per-component nodeSelector
  - SCHED-01 satisfied for Harbor: app pods and internal DB pinned to node-role=apps
  - SCHED-03 partially satisfied: Harbor pinned; topology spread omitted (single-replica components)
affects: [phase 03, future Harbor scaling work]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Harbor per-component nodeSelector at chart component root level (not chart top-level)"
    - "database.internal nodeSelector placed one indent deeper than other components"

key-files:
  created: []
  modified:
    - clusters/k3s-cluster/apps/harbor/helmrelease.yaml

key-decisions:
  - "topologySpreadConstraints intentionally omitted: all Harbor components run at replica=1 — topology spread provides no scheduling benefit and adds significant YAML complexity without value"
  - "pod anti-affinity intentionally omitted for database.internal: single-replica StatefulSet — anti-affinity only constrains pod-to-pod placement, with 1 replica there are never two pods of the same DB to separate"
  - "chartmuseum and notary sections untouched: both are disabled (enabled: false), adding scheduling to disabled components is unnecessary"
  - "nodeSelector added at registry root level (values.registry), not at values.registry.registry — Harbor chart places nodeSelector at component root"

patterns-established:
  - "Harbor scheduling: set nodeSelector per-component at component root level in helmrelease.yaml values"

requirements-completed: [SCHED-01, SCHED-03]

# Metrics
duration: 1min
completed: 2026-02-28
---

# Phase 2 Plan 4: Harbor Node Scheduling Summary

**All 8 Harbor component pods pinned to apps nodes via per-component nodeSelector {node-role: apps} in harbor-helm HelmRelease values**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-02-28T15:12:29Z
- **Completed:** 2026-02-28T15:13:30Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added `nodeSelector: {node-role: apps}` to all 8 Harbor component sections: core, portal, jobservice, registry, nginx, database.internal, trivy, exporter
- All existing Harbor configuration preserved (image repos/tags, securityContext, resources, persistence, metrics, ingress)
- Verified 8 occurrences of `node-role: apps` in the file — exactly one per component section
- SCHED-01 satisfied: Harbor application pods and internal database are pinned to apps node role
- SCHED-03 partially satisfied: Harbor pods are nodeSelector-pinned; topology spread correctly omitted for single-replica components

## Task Commits

Each task was committed atomically:

1. **Task 1: Add nodeSelector to all Harbor application component sections** - `894cb28` (feat)

## Files Created/Modified

- `clusters/k3s-cluster/apps/harbor/helmrelease.yaml` - Added per-component nodeSelector to 8 sections (core, portal, jobservice, registry, nginx, database.internal, trivy, exporter)

## Component Sections That Received nodeSelector

All 8 Harbor component sections received `nodeSelector: {node-role: apps}`:

| Component | Section Path | Notes |
|-----------|-------------|-------|
| core | `values.core` | At component root, before image block |
| portal | `values.portal` | At component root, before image block |
| jobservice | `values.jobservice` | At component root, before image block |
| registry | `values.registry` | At component root (NOT values.registry.registry) |
| nginx | `values.nginx` | At component root, before image block |
| database.internal | `values.database.internal` | One indent deeper; internal sub-section |
| trivy | `values.trivy` | At component root, before enabled flag |
| exporter | `values.exporter` | At component root, before image block |

## Decisions Made

- **topologySpreadConstraints omitted:** Every Harbor component runs at replica=1. Topology spread constraints at replica=1 provide zero scheduling benefit (there is only one pod to schedule) and would add 8+ blocks of complex YAML for no value. This is the correct engineering choice per RESEARCH.md Pattern 4 rationale.
- **pod anti-affinity omitted for database.internal:** Single-replica StatefulSet — anti-affinity constrains pod-to-pod placement; with 1 replica there are never two database pods to separate. Chart support for affinity on database.internal is also unclear.
- **chartmuseum and notary skipped:** Both are disabled (`enabled: false`). Adding scheduling configuration to components that will never schedule pods is unnecessary.
- **nodeSelector at registry root level:** The Harbor chart places per-component nodeSelector at `values.registry` (not at `values.registry.registry` or `values.registry.controller`). This is the correct path per chart architecture.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Harbor scheduling constraints complete
- All Harbor pods will schedule exclusively on nodes labeled `node-role=apps` once Flux reconciles
- Node labels must be applied imperatively on the cluster before this takes effect (documented blocker in STATE.md)
- redis section is untouched (uses external Redis, no Harbor-controlled scheduling)

---
*Phase: 02-scheduling-constraints*
*Completed: 2026-02-28*
