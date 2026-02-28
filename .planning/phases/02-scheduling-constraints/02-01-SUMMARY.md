---
phase: 02-scheduling-constraints
plan: 01
subsystem: infra
tags: [kubernetes, actions-runner-controller, scheduling, nodeSelector, topologySpreadConstraints, arc]

# Dependency graph
requires:
  - phase: 01-node-labeling
    provides: nodes labeled with node-role=runners so nodeSelector can match
provides:
  - nodeSelector pinning all 6 ARC runner scale sets to runner-labeled nodes
  - topologySpreadConstraints spreading runner pods across distinct nodes per set
affects: [phase 03 (replicated storage - no dependency), future runner scale set additions]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - nodeSelector with node-role key (not role) for runner node affinity
    - topologySpreadConstraints with ScheduleAnyway (soft) for runner pod spreading
    - labelSelector.matchLabels.app.kubernetes.io/name matching runnerScaleSetName

key-files:
  created: []
  modified:
    - clusters/k3s-cluster/apps/actions-runner-controller/runner-scale-set-helmrelease.yaml
    - clusters/k3s-cluster/apps/actions-runner-controller/claude-scale-set-helmrelease.yaml
    - clusters/k3s-cluster/apps/actions-runner-controller/code-quality-runner-helmrelease.yaml
    - clusters/k3s-cluster/apps/actions-runner-controller/dependabot-runner-scale-set-helmrelease.yaml
    - clusters/k3s-cluster/apps/actions-runner-controller/modbus-runner-set.yaml
    - clusters/k3s-cluster/apps/actions-runner-controller/opcua-runner-set.yaml

key-decisions:
  - "Use node-role (not role) as label key — consistent with Phase 1 decision"
  - "whenUnsatisfiable: ScheduleAnyway (not DoNotSchedule) — runners scale to zero; hard constraint would leave pods Pending on single-node runner pool"
  - "labelSelector.matchLabels.app.kubernetes.io/name set to runnerScaleSetName per file — matches chart-applied labels for correct topology tracking"
  - "6 runner sets found and updated (not 7) — operator HelmRelease excluded from scheduling constraints"

patterns-established:
  - "Runner HelmRelease scheduling pattern: nodeSelector + topologySpreadConstraints added to values.template.spec before first existing spec key"
  - "dependabot runner: scheduling constraints go before dnsPolicy (not securityContext, which does not exist at top level)"

requirements-completed: [RNRS-01, RNRS-02]

# Metrics
duration: 1min
completed: 2026-02-28
---

# Phase 2 Plan 01: Runner Scheduling Constraints Summary

**nodeSelector pinning all 6 ARC runner scale sets to node-role=runners nodes with ScheduleAnyway topologySpreadConstraints across kubernetes.io/hostname**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-02-28T15:12:22Z
- **Completed:** 2026-02-28T15:12:42Z
- **Tasks:** 2
- **Files modified:** 6 (3 already committed in prior session, 3 committed now)

## Accomplishments
- All 6 runner HelmReleases have `template.spec.nodeSelector: {node-role: runners}` pinning pods to runner nodes
- All 6 runner HelmReleases have `topologySpreadConstraints` with `topologyKey: kubernetes.io/hostname` and `whenUnsatisfiable: ScheduleAnyway`
- Each `labelSelector.matchLabels.app.kubernetes.io/name` correctly matches the `runnerScaleSetName` in each file
- Dependabot runner's complex spec (dnsPolicy, dnsConfig, initContainers, dind container, multiple volumes) fully preserved

## Task Commits

Each task was committed atomically:

1. **Task 1: arc-runner-set, claude-runner-set, code-quality-runner** - `0ad3948` (feat) — committed in prior session
2. **Task 2: dependabot, modbus-runner-set, opcua-runner-set** - `b150956` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `clusters/k3s-cluster/apps/actions-runner-controller/runner-scale-set-helmrelease.yaml` - Added nodeSelector + topologySpreadConstraints (app.kubernetes.io/name: arc-runner-set)
- `clusters/k3s-cluster/apps/actions-runner-controller/claude-scale-set-helmrelease.yaml` - Added nodeSelector + topologySpreadConstraints (app.kubernetes.io/name: claude-runner-set)
- `clusters/k3s-cluster/apps/actions-runner-controller/code-quality-runner-helmrelease.yaml` - Added nodeSelector + topologySpreadConstraints (app.kubernetes.io/name: code-quality-runner)
- `clusters/k3s-cluster/apps/actions-runner-controller/dependabot-runner-scale-set-helmrelease.yaml` - Added nodeSelector + topologySpreadConstraints before dnsPolicy (app.kubernetes.io/name: dependabot)
- `clusters/k3s-cluster/apps/actions-runner-controller/modbus-runner-set.yaml` - Added nodeSelector + topologySpreadConstraints (app.kubernetes.io/name: modbus-runner-set)
- `clusters/k3s-cluster/apps/actions-runner-controller/opcua-runner-set.yaml` - Added nodeSelector + topologySpreadConstraints (app.kubernetes.io/name: opcua-runner-set)

## Decisions Made

- **node-role key (not role):** REQUIREMENTS.md erroneously used `role=runners`; Phase 1 locked the key as `node-role`. All files use `node-role: runners` consistently.
- **ScheduleAnyway:** Hard constraint (`DoNotSchedule`) would leave runner pods Pending if runner pool has only one node at scale-down. Soft spreading avoids this edge case.
- **labelSelector per file:** Each file's `app.kubernetes.io/name` matches its `runnerScaleSetName` — this is the label the gha-runner-scale-set chart applies to runner pods, ensuring topology tracking works correctly.
- **6 files, not 7:** The operator HelmRelease (`actions-runner-controller`) manages the ARC controller itself, not runner pods — excluded from scheduling constraints correctly.

## Deviations from Plan

None - plan executed exactly as written. Task 1 files (arc, claude, code-quality) were already committed in a prior session (0ad3948); Task 2 (dependabot, modbus, opcua) was committed fresh as b150956.

## Issues Encountered

Task 1 changes for arc-runner-set, claude-runner-set, and code-quality-runner were already present in HEAD (committed as part of 0ad3948 in a prior session). The edit operations confirmed the text was already present; git showed no diff. Execution continued directly to Task 2 without re-committing.

## User Setup Required

None - no external service configuration required. Node labels must be applied imperatively on the cluster before these scheduling constraints take effect (pre-existing blocker noted in STATE.md).

## Next Phase Readiness

- All 6 runner HelmReleases have scheduling constraints configured
- Requirements RNRS-01 and RNRS-02 satisfied
- Constraints are syntactically valid GitOps configuration; will take effect once Phase 1 node labels are applied on the cluster
- Phase 3 (replicated storage) can proceed in parallel — no dependency

---
*Phase: 02-scheduling-constraints*
*Completed: 2026-02-28*
