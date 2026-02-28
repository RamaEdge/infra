# Phase 1: Node Labeling - Context

**Gathered:** 2026-02-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Define a node labeling scheme with 3 roles (infra, apps, runners), create an idempotent shell script to apply labels, and document the scheme. Labels are applied imperatively on the cluster — this phase produces the script and docs, not Kubernetes manifests.

</domain>

<decisions>
## Implementation Decisions

### Role Assignment Strategy
- Nodes can have multiple roles (overlap allowed) — with 4-6 nodes and 3 roles, strict isolation isn't practical
- **infra role**: Everything non-app — monitoring stack (Prometheus, Grafana, Loki, OpenTelemetry), Keycloak SSO, MinIO storage, cluster services
- **apps role**: All developer-facing services — Forgejo, Harbor, DevPI
- **runners role**: 1-2 dedicated nodes for GitHub Actions runners, Claude picks based on cluster size
- A node can be both `apps` and `infra` if needed for capacity

### Label Taxonomy
- Label key: `node-role` (e.g., `node-role=infra`) — avoids conflict with k8s built-in `node-role.kubernetes.io/`
- Just role labels for now — no additional storage tier or arch labels
- Multiple roles on one node: apply multiple labels or comma-separated value (Claude decides format)

### Script Behavior
- Config file driven — read node-to-role mapping from a YAML or JSON config file
- Idempotent — safe to re-run (`kubectl label --overwrite`)
- Verify after applying — show summary of all nodes with their role assignments
- Location: `scripts/` directory at repo root (new directory)

### Documentation
- Dual location: usage in script header + detailed guide in `docs/node-labeling.md`
- Matches existing `docs/sso/` pattern for operational docs
- Depth: operational runbook — step-by-step for relabeling, adding new nodes, troubleshooting

### Claude's Discretion
- Config file format (YAML vs JSON) for node-to-role mapping
- Exact script structure and error handling
- How to handle nodes with multiple roles (multiple labels vs single comma-separated value)
- Summary output format after label verification

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Key constraint: must work with k3s ARM64 cluster.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/` directory exists with operational guides (SSO integration, filesystem corruption)
- `SETUP_COMMANDS.md` and `DEPLOYMENT.md` provide patterns for operational documentation

### Established Patterns
- YAML is the dominant format — config file should likely be YAML for consistency
- Lowercase-hyphenated naming convention throughout the repo
- Docs follow operational runbook style (step-by-step with commands)

### Integration Points
- Phase 2 (Scheduling Constraints) references these labels via `nodeSelector` and `nodeAffinity` in HelmReleases
- Label key chosen here (`node-role`) must match what Phase 2 uses in scheduling manifests
- Script location (`scripts/`) sets precedent for future operational scripts

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-node-labeling*
*Context gathered: 2026-02-28*
