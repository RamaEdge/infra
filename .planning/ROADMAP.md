# Roadmap: Infrastructure Production Hardening

## Overview

Three phases transform the cluster from single-point-of-failure to fault-tolerant: first establish node roles as the scheduling foundation, then apply topology constraints so workloads spread across nodes, then switch critical PVCs to replicated storage so data survives node loss.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Node Labeling** - Define node roles and produce the imperative script to apply labels
- [ ] **Phase 2: Scheduling Constraints** - Spread ARC runners and stateful workloads across nodes using node roles
- [ ] **Phase 3: Replicated Storage** - Create longhorn-replicated StorageClass and switch all critical PVCs to it

## Phase Details

### Phase 1: Node Labeling
**Goal**: Node roles are defined, documented, and the cluster can be labeled with a single script
**Depends on**: Nothing (first phase)
**Requirements**: NODE-01, NODE-02, NODE-03
**Success Criteria** (what must be TRUE):
  1. Three node roles (infra, apps, runners) are defined with clear assignment guidance
  2. A shell script exists that applies all node labels to the cluster in one run
  3. Documentation states which workloads target which role so operators can assign new nodes correctly
**Plans**: TBD

### Phase 2: Scheduling Constraints
**Goal**: All 7 ARC runner scale sets and stateful workloads are scheduled according to node roles with topology spread
**Depends on**: Phase 1
**Requirements**: RNRS-01, RNRS-02, SCHED-01, SCHED-02, SCHED-03
**Success Criteria** (what must be TRUE):
  1. All 7 ARC runner HelmReleases have topologySpreadConstraints on `kubernetes.io/hostname` — no two runners of the same set land on the same node
  2. ARC runner scale sets are pinned to nodes labeled `role=runners` via nodeSelector
  3. Stateful workloads (databases, Forgejo, Harbor) have nodeAffinity targeting their appropriate node roles
  4. PostgreSQL instances have pod anti-affinity so no two database pods share a node
**Plans**: TBD

### Phase 3: Replicated Storage
**Goal**: Critical stateful data is stored on replicated Longhorn volumes that survive a single-node failure
**Depends on**: Phase 1
**Requirements**: STOR-01, STOR-02, STOR-03, STOR-04, STOR-05, STOR-06
**Success Criteria** (what must be TRUE):
  1. A `longhorn-replicated` StorageClass exists with replica count 2 or higher
  2. Forgejo app data PVC (200Gi) uses longhorn-replicated
  3. All four PostgreSQL PVCs (Forgejo, Keycloak, Harbor, Smedja) use longhorn-replicated
  4. Default StorageClass remains unchanged — non-critical workloads are unaffected
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Node Labeling | 0/TBD | Not started | - |
| 2. Scheduling Constraints | 0/TBD | Not started | - |
| 3. Replicated Storage | 0/TBD | Not started | - |
