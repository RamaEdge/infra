# Requirements: Infrastructure Production Hardening

**Defined:** 2026-02-28
**Core Value:** Critical stateful data survives node failures; workloads distributed evenly across nodes

## v1 Requirements

### Runner Scheduling

- [ ] **RNRS-01**: All 7 ARC runner scale sets have topologySpreadConstraints with key `kubernetes.io/hostname`
- [ ] **RNRS-02**: Runner scale sets have nodeSelector pinning runners to nodes labeled `role=runners`

### Node Labeling

- [ ] **NODE-01**: Node labeling scheme defined (role=infra, role=apps, role=runners)
- [ ] **NODE-02**: Shell script generated to apply node labels to cluster nodes
- [ ] **NODE-03**: Documentation of labeling scheme and which workloads target which roles

### Workload Scheduling

- [x] **SCHED-01**: Stateful workloads (databases, Forgejo, Harbor) have nodeAffinity targeting appropriate node roles
- [ ] **SCHED-02**: PostgreSQL instances have pod anti-affinity to prevent co-location on same node
- [x] **SCHED-03**: Application pods have topologySpreadConstraints to spread across nodes

### Replicated Storage

- [ ] **STOR-01**: longhorn-replicated StorageClass defined with replica count 2+
- [ ] **STOR-02**: Forgejo app data PVC (200Gi) uses longhorn-replicated
- [ ] **STOR-03**: Forgejo PostgreSQL PVC (1Gi) uses longhorn-replicated
- [ ] **STOR-04**: Keycloak PostgreSQL PVC (1Gi) uses longhorn-replicated
- [ ] **STOR-05**: Harbor PostgreSQL PVC (1Gi) uses longhorn-replicated
- [ ] **STOR-06**: Smedja PostgreSQL PVC (10Gi) uses longhorn-replicated

## v2 Requirements

### Advanced Scheduling

- **ASCHED-01**: Priority classes for critical vs non-critical workloads
- **ASCHED-02**: Pod disruption budgets for stateful services
- **ASCHED-03**: Resource quotas per namespace

### Storage

- **ASTOR-01**: Automated backup schedule for replicated volumes
- **ASTOR-02**: Storage monitoring alerts for capacity thresholds

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-replica deployments | Optimized for edge/ARM single-replica pattern |
| Automated node provisioning | Nodes are manually managed |
| Network policies | Separate hardening concern |
| Backup/restore procedures | Separate operational concern |
| Cluster autoscaling | Fixed node count, manual scaling |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| NODE-01 | Phase 1 | Pending |
| NODE-02 | Phase 1 | Pending |
| NODE-03 | Phase 1 | Pending |
| RNRS-01 | Phase 2 | Pending |
| RNRS-02 | Phase 2 | Pending |
| SCHED-01 | Phase 2 | Complete |
| SCHED-02 | Phase 2 | Pending |
| SCHED-03 | Phase 2 | Complete |
| STOR-01 | Phase 3 | Pending |
| STOR-02 | Phase 3 | Pending |
| STOR-03 | Phase 3 | Pending |
| STOR-04 | Phase 3 | Pending |
| STOR-05 | Phase 3 | Pending |
| STOR-06 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0

---
*Requirements defined: 2026-02-28*
*Last updated: 2026-02-28 after roadmap creation*
