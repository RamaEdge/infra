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

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Topology key `kubernetes.io/hostname` chosen — spreading across nodes, not zones (single-site cluster)
- Node roles: infra/apps/runners — clean scheduling separation
- Script + docs for labeling — reproducible without putting imperative commands in GitOps repo
- `longhorn-replicated` as new StorageClass — preserves default for non-critical workloads, explicit opt-in
- New deploys only, no data migration — PVCs are for fresh deployments

### Pending Todos

None yet.

### Blockers/Concerns

- Node labels must be applied imperatively on the cluster before Phase 2 scheduling constraints take effect — Phase 2 Flux changes will be syntactically valid but won't schedule correctly until labels are applied
- Phase 3 can proceed in parallel with Phase 2 (no dependency between them)

## Session Continuity

Last session: 2026-02-28
Stopped at: Roadmap created, no phases planned yet
Resume file: None
