# Phase 1: Node Labeling - Research

**Researched:** 2026-02-28
**Domain:** Kubernetes node labeling, shell scripting (Bash), YAML config, operational runbook documentation
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Nodes can have multiple roles (overlap allowed) — with 4-6 nodes and 3 roles, strict isolation is not practical
- **infra role**: Everything non-app — monitoring stack (Prometheus, Grafana, Loki, OpenTelemetry), Keycloak SSO, MinIO storage, cluster services
- **apps role**: All developer-facing services — Forgejo, Harbor, DevPI
- **runners role**: 1-2 dedicated nodes for GitHub Actions runners, Claude picks based on cluster size
- A node can be both `apps` and `infra` if needed for capacity
- Label key: `node-role` (e.g., `node-role=infra`) — avoids conflict with k8s built-in `node-role.kubernetes.io/`
- Just role labels for now — no additional storage tier or arch labels
- Multiple roles on one node: apply multiple labels or comma-separated value (Claude decides format)
- Config file driven — read node-to-role mapping from a YAML or JSON config file
- Idempotent — safe to re-run (`kubectl label --overwrite`)
- Verify after applying — show summary of all nodes with their role assignments
- Script location: `scripts/` directory at repo root (new directory)
- Dual documentation location: usage in script header + detailed guide in `docs/node-labeling.md`
- Matches existing `docs/sso/` pattern for operational docs
- Depth: operational runbook — step-by-step for relabeling, adding new nodes, troubleshooting

### Claude's Discretion

- Config file format (YAML vs JSON) for node-to-role mapping
- Exact script structure and error handling
- How to handle nodes with multiple roles (multiple labels vs single comma-separated value)
- Summary output format after label verification

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NODE-01 | Node labeling scheme defined (role=infra, role=apps, role=runners) | Label key `node-role`, three roles, multiple roles per node via separate label entries |
| NODE-02 | Shell script generated to apply node labels to cluster nodes | `kubectl label node --overwrite` with YAML config file driver; `yq` or Python for parsing |
| NODE-03 | Documentation of labeling scheme and which workloads target which roles | Operational runbook at `docs/node-labeling.md` matching `docs/sso/` style |
</phase_requirements>

---

## Summary

This phase is a pure operational tooling phase — no Kubernetes manifests are created, no Flux changes occur. The output is a Bash script plus documentation. The technical domain is simple: `kubectl label node` with `--overwrite` is the core primitive; the complexity lies in designing the config-driven approach cleanly and writing a clear runbook.

The label taxonomy decision (`node-role=infra`, `node-role=apps`, `node-role=runners`) is already locked. The key implementation question is multi-role handling. The correct approach is **multiple distinct labels per node using distinct keys** (e.g., `node-role.infra=true` and `node-role.apps=true`) rather than a single `node-role=infra,apps` value — because Kubernetes label selectors (used by Phase 2's `nodeSelector` and `nodeAffinity`) match on individual label key-value pairs, not comma-separated values within a single label. This is the most critical architectural decision for downstream compatibility.

The config file should use YAML (not JSON) for consistency with the repository's dominant format. The script must handle nodes not yet registered in the config gracefully, and the verification step should present a clear tabular summary using `kubectl get nodes --show-labels` or a formatted `kubectl get nodes -o wide` output.

**Primary recommendation:** Use distinct boolean-style label keys per role (`node-role.infra=true`, `node-role.apps=true`, `node-role.runners=true`) driven by a YAML config file, applied via an idempotent Bash script using `kubectl label node --overwrite`.

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `kubectl` | Cluster's k8s version (1.24+) | Apply labels, verify state | Native Kubernetes CLI — no alternatives |
| Bash | System bash (4+) | Script interpreter | Established pattern in this repo (`SETUP_COMMANDS.md`, `DEPLOYMENT.md`); no dependencies |
| YAML | - | Config file format | Dominant format throughout the repo; all contributors already write YAML |
| `yq` | v4.x | Parse YAML config in Bash | Lightweight, single binary, ARM64 compatible; widely used for k8s operational scripts |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `python3` | System Python | Alternative YAML parser | Use if `yq` is unavailable on the cluster operator's machine |
| `kubectl get nodes -o json` + `jq` | System jq | JSON alternative for parsing | Fallback if YAML parsing tools unavailable |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `yq` for YAML parsing | `python3 -c "import yaml"` | Python is universally available but verbose; yq is purpose-built and cleaner |
| YAML config file | JSON config file | JSON has no comments; YAML matches repo convention and is more human-editable |
| Multiple boolean labels | Single comma-separated value label | Comma-separated values cannot be matched by `nodeSelector` — incompatible with Phase 2 |

**Installation note:** `yq` is not a cluster component — it runs on the operator's workstation. It is available via `brew install yq` (macOS) or `wget` for ARM64 Linux. The script should detect if `yq` is absent and print a clear install instruction rather than failing silently.

---

## Architecture Patterns

### Recommended Project Structure

```
scripts/
└── apply-node-labels.sh        # Main script (executable, +x)

scripts/
└── node-roles.yaml             # Config file: node-to-role mapping

docs/
└── node-labeling.md            # Operational runbook
```

### Pattern 1: Multiple Boolean Labels per Role

**What:** Each role is a separate label key with value `"true"`. A node with two roles has two label entries.

**When to use:** Always — this is the only format compatible with `nodeSelector` and `nodeAffinity` in Phase 2.

**Example config (`scripts/node-roles.yaml`):**
```yaml
# Node role assignments for k3s-cluster
# Multiple roles per node are allowed
nodes:
  - name: node-01
    roles:
      - infra
      - apps
  - name: node-02
    roles:
      - apps
  - name: node-03
    roles:
      - runners
  - name: node-04
    roles:
      - runners
```

**Example label application:**
```bash
# For each role in node's role list:
kubectl label node node-01 node-role.infra=true --overwrite
kubectl label node node-01 node-role.apps=true --overwrite
kubectl label node node-03 node-role.runners=true --overwrite
```

**Phase 2 nodeSelector compatibility:**
```yaml
# In HelmRelease values (Phase 2) — selects infra nodes:
nodeSelector:
  node-role.infra: "true"

# Selects runner nodes:
nodeSelector:
  node-role.runners: "true"
```

### Pattern 2: Idempotent Script with Pre-flight Checks

**What:** Script validates `kubectl` connectivity and `yq` availability before doing anything; uses `--overwrite` on every label apply; produces a verification summary after all labels are applied.

**Example script structure:**
```bash
#!/usr/bin/env bash
# apply-node-labels.sh
# Applies node role labels to k3s cluster nodes from a YAML config file.
# Usage: ./scripts/apply-node-labels.sh [--config scripts/node-roles.yaml] [--dry-run]
# Idempotent: safe to run multiple times.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${1:-${SCRIPT_DIR}/node-roles.yaml}"
DRY_RUN="${DRY_RUN:-false}"

# --- Pre-flight checks ---
check_dependency() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 not found. Install: $2"; exit 1; }; }
check_dependency kubectl "https://kubernetes.io/docs/tasks/tools/"
check_dependency yq "brew install yq  OR  https://github.com/mikefarah/yq/releases"

# Verify cluster access
kubectl cluster-info >/dev/null 2>&1 || { echo "ERROR: Cannot reach cluster. Check KUBECONFIG."; exit 1; }

# --- Apply labels ---
NODE_COUNT=$(yq '.nodes | length' "$CONFIG_FILE")
for i in $(seq 0 $((NODE_COUNT - 1))); do
  NODE_NAME=$(yq ".nodes[$i].name" "$CONFIG_FILE")
  ROLE_COUNT=$(yq ".nodes[$i].roles | length" "$CONFIG_FILE")
  for j in $(seq 0 $((ROLE_COUNT - 1))); do
    ROLE=$(yq ".nodes[$i].roles[$j]" "$CONFIG_FILE")
    LABEL_KEY="node-role.${ROLE}"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY RUN] kubectl label node ${NODE_NAME} ${LABEL_KEY}=true --overwrite"
    else
      kubectl label node "${NODE_NAME}" "${LABEL_KEY}=true" --overwrite
      echo "  Labeled: ${NODE_NAME} -> ${LABEL_KEY}=true"
    fi
  done
done

# --- Verification summary ---
echo ""
echo "=== Node Role Summary ==="
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,\
INFRA:.metadata.labels.node-role\.infra,\
APPS:.metadata.labels.node-role\.apps,\
RUNNERS:.metadata.labels.node-role\.runners'
```

### Pattern 3: Operational Runbook Structure (matching `docs/sso/`)

The existing `docs/sso/` docs follow this structure: overview, prerequisites, numbered steps with commands, troubleshooting. The new `docs/node-labeling.md` should follow the same format:

```markdown
# Node Labeling Guide
## Overview
## Node Roles
## Workload-to-Role Mapping
## Prerequisites
## Applying Labels (First Time)
## Adding a New Node
## Relabeling a Node
## Removing a Role from a Node
## Troubleshooting
```

### Anti-Patterns to Avoid

- **Single comma-separated label value** (`node-role=infra,apps`): Kubernetes label selectors cannot match partial values — `nodeSelector: {node-role: infra}` will NOT match this. Must use separate labels.
- **Using `node-role.kubernetes.io/` prefix**: This is a reserved Kubernetes well-known label prefix. Using it without the system's expectations causes confusion and potential conflicts.
- **Hardcoding node names in the script**: Config file must be the source of truth — the script should only read from config, never have node names embedded.
- **Not using `--overwrite`**: Without `--overwrite`, re-running the script will fail with "already has label" errors.
- **Failing silently on missing nodes**: If a node in the config doesn't exist in the cluster, the script should warn clearly and continue (not silently skip or hard-fail).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML parsing in Bash | Custom awk/sed YAML parser | `yq` v4 | Parsing YAML with awk is fragile; yq handles nested structures, arrays, and quoting correctly |
| Kubernetes connectivity check | Custom HTTP probe | `kubectl cluster-info` | Built-in, respects KUBECONFIG, handles auth correctly |
| Node existence check | Custom API call | `kubectl get node $NAME` exit code | Clean, handles all auth and error cases |

**Key insight:** The script logic is simple; the value is in correctness guarantees (idempotency, pre-flight checks, clear output) not in complexity.

---

## Common Pitfalls

### Pitfall 1: Label Key Format and Phase 2 Compatibility

**What goes wrong:** Using `node-role=infra` (single label, single value) works for display but breaks `nodeSelector` when a node has multiple roles, because `nodeSelector: {node-role: infra}` only matches nodes where the label value is exactly `infra` — not `infra,apps`.

**Why it happens:** The CONTEXT.md mentions "multiple roles on one node" as needing a format decision. Choosing comma-separated values seems elegant but is incompatible with Kubernetes label matching semantics.

**How to avoid:** Use separate label keys per role: `node-role.infra=true`, `node-role.apps=true`, `node-role.runners=true`. Phase 2 then selects by key presence, not value.

**Warning signs:** If Phase 2 scheduling works for single-role nodes but fails for dual-role nodes, this is the cause.

### Pitfall 2: yq v3 vs v4 Syntax Differences

**What goes wrong:** `yq` has two incompatible major versions. v3 (older) uses `yq r file.yaml 'path'`; v4 (current) uses `yq '.path' file.yaml`. Scripts written for v4 fail silently or produce wrong output on v3.

**Why it happens:** `brew install yq` installs v4, but some Linux systems may have v3 packaged.

**How to avoid:** Script should check `yq --version` and fail with a clear message if v3 is detected.

**Warning signs:** `yq` commands return empty strings or error messages about unknown flags.

### Pitfall 3: Node Names Not Matching Cluster Reality

**What goes wrong:** Config file uses names like `node-01` but cluster nodes are registered as `k3s-node-01.local` or IP addresses. Labels apply to wrong nodes or kubectl fails with "not found."

**Why it happens:** k3s registers nodes with the hostname at registration time, which may differ from short names.

**How to avoid:** Script should verify each node exists before labeling (`kubectl get node $NAME`) and print a warning if not found rather than failing the entire run.

**Warning signs:** `kubectl label node` returns "Error from server (NotFound)."

### Pitfall 4: Script Not Executable

**What goes wrong:** `scripts/apply-node-labels.sh` exists in git but `chmod +x` was never set, causing `permission denied` errors.

**Why it happens:** Files created with editors default to non-executable. Git tracks the execute bit but only if explicitly set.

**How to avoid:** Set execute bit before committing: `chmod +x scripts/apply-node-labels.sh`. Verify with `git ls-files --stage scripts/apply-node-labels.sh` — mode should be `100755` not `100644`.

---

## Code Examples

Verified patterns based on official Kubernetes documentation (HIGH confidence):

### Applying a Node Label with Overwrite
```bash
# Source: kubectl label documentation (kubernetes.io/docs/reference/kubectl/generated/kubectl_label/)
kubectl label node node-01 node-role.infra=true --overwrite
```

### Removing a Node Label
```bash
# Remove label by appending '-' to the key (for runbook "remove a role" section)
kubectl label node node-01 node-role.infra-
```

### Viewing Node Labels (Custom Columns)
```bash
# Display role labels in a clean table
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,INFRA:.metadata.labels.node-role\.infra,APPS:.metadata.labels.node-role\.apps,RUNNERS:.metadata.labels.node-role\.runners'
```

### Viewing All Labels on Nodes
```bash
kubectl get nodes --show-labels
```

### yq Array Iteration (v4 syntax)
```bash
# Source: mikefarah/yq documentation
# Count items in array
COUNT=$(yq '.nodes | length' node-roles.yaml)

# Get specific nested value
NAME=$(yq '.nodes[0].name' node-roles.yaml)
ROLE=$(yq '.nodes[0].roles[0]' node-roles.yaml)
```

### Checking Node Existence Before Labeling
```bash
if kubectl get node "$NODE_NAME" >/dev/null 2>&1; then
  kubectl label node "$NODE_NAME" "${LABEL_KEY}=true" --overwrite
else
  echo "WARNING: Node '$NODE_NAME' not found in cluster — skipping"
fi
```

### Verifying yq Version
```bash
YQ_MAJOR=$(yq --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f1)
if [[ "$YQ_MAJOR" -lt 4 ]]; then
  echo "ERROR: yq v4+ required (found v${YQ_MAJOR}). Install: brew install yq"
  exit 1
fi
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded `kubectl label` commands in runbooks | Config-driven scripts | Ongoing best practice | Declarative, git-trackable, reproducible |
| `node-role.kubernetes.io/` prefix for custom roles | Custom prefix (`node-role.`) | k8s 1.17+ (well-known labels formalized) | Avoids reserved prefix conflicts |
| Manual label verification | Script-generated summary table | N/A | Operators immediately see current state after apply |

**Note on k3s ARM64 compatibility:** k3s fully supports ARM64 and `kubectl label node` has no architecture dependency. This is a pure control-plane operation. No ARM64-specific handling is needed in the labeling script itself.

---

## Open Questions

1. **Actual node hostnames in the cluster**
   - What we know: 4-6 nodes exist; node names are not documented in the repo
   - What's unclear: Exact registered hostnames (short names vs FQDN vs IPs)
   - Recommendation: The config file (`node-roles.yaml`) ships with placeholder names. The operator must populate it with actual `kubectl get nodes` output before running the script. Document this step explicitly in the runbook.

2. **How many nodes get the `runners` role**
   - What we know: 1-2 dedicated nodes for runners; Claude decides based on cluster size
   - What's unclear: Cluster has 4-6 nodes — exact count unknown
   - Recommendation: Default config should show 1 runner node for a 4-node cluster, 2 for 6-node. Document the guidance rule in `docs/node-labeling.md`.

3. **`--dry-run` flag implementation**
   - What we know: Locked decisions don't mention dry-run, but it is standard practice for operational scripts
   - What's unclear: Whether to implement as a CLI flag or env variable
   - Recommendation: Implement as `DRY_RUN=true ./scripts/apply-node-labels.sh` env variable — simpler and consistent with common k8s tooling patterns.

---

## Sources

### Primary (HIGH confidence)

- Kubernetes official docs — `kubectl label` command: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_label/
- Kubernetes official docs — Labels and Selectors: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
- Kubernetes official docs — Well-Known Labels: https://kubernetes.io/docs/reference/labels-annotations-taints/
- yq v4 official docs — https://mikefarah.gitbook.io/yq/

### Secondary (MEDIUM confidence)

- k3s documentation on node registration: https://docs.k3s.io/architecture — confirms standard Kubernetes node labeling applies without modification
- Existing codebase patterns (`clusters/k3s-cluster/apps/minio/tenant.yaml`) — confirms `nodeSelector` key-value format expected by workloads

### Tertiary (LOW confidence)

- None required for this phase — domain is well-established Kubernetes fundamentals

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — kubectl and bash are fixed; yq is well-established for this pattern
- Architecture: HIGH — Kubernetes label semantics are stable and well-documented; multiple-key approach is the only correct approach for multi-role nodes
- Pitfalls: HIGH — yq version issue and label format are documented Kubernetes community knowledge; node-name mismatch is a common operational mistake

**Research date:** 2026-02-28
**Valid until:** 2026-09-01 (stable domain — kubectl label API has not changed in years)
