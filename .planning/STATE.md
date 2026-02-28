---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: unknown
last_updated: "2026-02-28T15:14:14.388Z"
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 8
  completed_plans: 3
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-28)

**Core value:** Critical stateful data survives node failures through replicated storage; workloads distributed evenly across nodes
**Current focus:** Phase 1 - Node Labeling

## Current Position

Phase: 1 of 3 (Node Labeling)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-02-28 — Roadmap created

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
| Phase 02-scheduling-constraints P03 | 1 | 2 tasks | 2 files |
| Phase 02-scheduling-constraints P04 | 1 | 1 tasks | 1 files |
| Phase 02-scheduling-constraints P02 | 3 | 2 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Topology key `kubernetes.io/hostname` chosen — spreading across nodes, not zones (single-site cluster)
- Node roles: infra/apps/runners — clean scheduling separation
- Script + docs for labeling — reproducible without putting imperative commands in GitOps repo
- `longhorn-replicated` as new StorageClass — preserves default for non-critical workloads, explicit opt-in
- New deploys only, no data migration — PVCs are for fresh deployments
- [Phase 02-scheduling-constraints]: Forgejo topologySpreadConstraints uses ScheduleAnyway (single-replica; hard constraint risks unschedulability)
- [Phase 02-scheduling-constraints]: Keycloak uses nodeSelector only — keycloakx chart renders affinity via tpl (Go template), overriding it replaces default podAntiAffinity
- [Phase 02-scheduling-constraints]: topologySpreadConstraints omitted for Harbor: all components run at replica=1, spread provides no benefit
- [Phase 02-scheduling-constraints]: Harbor nodeSelector set per-component at chart root level, not top-level; database.internal is nested one level deeper
- [Phase 02-scheduling-constraints]: Used Bitnami nodeAffinityPreset (not raw affinity block) — preset is silently ignored when primary.affinity is also set
- [Phase 02-scheduling-constraints]: forgejo-db targets apps node role; keycloak-db targets infra node role — consistent with Phase 1 node role assignments
- [Phase 02-scheduling-constraints]: podAntiAffinityPreset: hard set on both PostgreSQL HelmReleases — no effect at replica=1 but correctly documents co-location prevention intent

### Pending Todos

None yet.

### Blockers/Concerns

- Node labels must be applied imperatively on the cluster before Phase 2 scheduling constraints take effect — Phase 2 Flux changes will be syntactically valid but won't schedule correctly until labels are applied
- Phase 3 can proceed in parallel with Phase 2 (no dependency between them)

## Session Continuity

Last session: 2026-02-28
Stopped at: Roadmap created, no phases planned yet
Resume file: None
