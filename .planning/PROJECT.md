# Infrastructure Production Hardening

## What This Is

Production hardening for the k3s Kubernetes cluster managed via Flux CD GitOps. This work improves workload distribution, fault tolerance, and data durability across a 4-6 node cluster by adding topology constraints, node-based scheduling, and replicated storage for critical stateful workloads.

## Core Value

Critical stateful data (git repos, databases) survives node failures through replicated storage, and workloads are evenly distributed across nodes to prevent resource hotspots.

## Requirements

### Validated

- ✓ GitOps deployment via Flux CD — existing
- ✓ Longhorn block storage for persistent volumes — existing
- ✓ ARC runner scale sets (7 sets, 0-10 scaling) — existing
- ✓ Namespace isolation per application — existing
- ✓ Prometheus/Grafana monitoring stack — existing
- ✓ Keycloak SSO with OIDC integration — existing
- ✓ Harbor container registry — existing
- ✓ Forgejo git hosting — existing
- ✓ Ingress with TLS termination — existing

### Active

- [ ] TopologySpreadConstraints on all 7 ARC runner scale sets (spread across nodes via `kubernetes.io/hostname`)
- [ ] Node labeling scheme (role=infra, role=apps, role=runners) with script + documentation
- [ ] nodeSelector/nodeAffinity on stateful workloads to spread heavy apps across nodes
- [ ] longhorn-replicated StorageClass creation (replica count 2+)
- [ ] Switch Forgejo app data PVC (200Gi) to longhorn-replicated
- [ ] Switch Forgejo PostgreSQL PVC (1Gi) to longhorn-replicated
- [ ] Switch Keycloak PostgreSQL PVC (1Gi) to longhorn-replicated
- [ ] Switch Harbor PostgreSQL PVC (1Gi) to longhorn-replicated
- [ ] Switch Smedja PostgreSQL PVC (10Gi) to longhorn-replicated

### Out of Scope

- Multi-cluster federation — single cluster focus
- Automated node provisioning — nodes are manually managed
- Application-level HA (multi-replica deployments) — optimized for edge/ARM with single replicas
- Backup/restore procedures — separate concern
- Network policies — not part of this hardening pass

## Context

- Cluster runs k3s on ARM64 nodes (4-6 nodes)
- **Two-repo architecture:**
  - `infra-core` (`/Users/ravichillerega/sources/core/infra-core`) — Cluster foundation: Longhorn, MetalLB, Flux, StorageClasses, node config
  - `infra` (`/Users/ravichillerega/sources/core/infra`) — Applications on top: Forgejo, Harbor, Keycloak, ARC runners, monitoring
- All deployments managed via Flux CD HelmReleases
- Longhorn provides distributed block storage but currently uses default (likely single-replica) storage class
- ARC runners currently have no topology constraints, may pile onto a single node
- Stateful workloads (databases, git repos) have no scheduling preferences, may co-locate on one node
- Node labeling is imperative (done on cluster, not in this repo) — repo changes reference labels
- PVCs are for new deployments, no data migration needed

### Repo Split

| Work Item | Target Repo |
|-----------|-------------|
| Phase 1: Node labeling tooling (scripts, docs) | `infra-core` — handled manually |
| Phase 3 Plan 01: `longhorn-replicated` StorageClass | `infra-core` — handled manually |
| Phase 2: All scheduling constraints | `infra` — automated via GSD |
| Phase 3 Plans 02-04: PVC changes | `infra` — automated via GSD |

## Constraints

- **GitOps**: All repo changes must be valid Flux CD manifests — HelmRelease values, Kustomizations
- **Imperative vs Declarative**: Node labels applied imperatively on cluster; only scheduling references go in repo
- **ARM64**: All workloads must remain ARM64-compatible
- **Storage**: Longhorn is the only storage provider; replicated class needs to be defined

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Topology key: `kubernetes.io/hostname` | Spreading across nodes (not zones) matches single-site cluster | — Pending |
| Node roles: infra/apps/runners | Clean separation of concerns for scheduling | — Pending |
| Script + docs for node labeling | Reproducible labeling without putting imperative commands in GitOps repo | — Pending |
| longhorn-replicated as new StorageClass | Preserves default class for non-critical workloads, explicit opt-in for replication | — Pending |
| New deploys (no migration) | PVCs are for fresh deployments, no existing data to preserve | — Pending |

---
*Last updated: 2026-02-28 after initialization*
