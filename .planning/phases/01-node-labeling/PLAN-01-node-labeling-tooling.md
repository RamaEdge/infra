---
plan: PLAN-01-node-labeling-tooling
phase: 1
wave: 1
depends_on: []
requirements:
  - NODE-01
  - NODE-02
  - NODE-03
files_modified:
  - scripts/node-roles.yaml
  - scripts/apply-node-labels.sh
  - docs/node-labeling.md
autonomous: true
---

# Plan: Node Labeling Tooling

## Objective

Produce the complete operational tooling for node labeling: a YAML config defining role assignments (NODE-01), an idempotent Bash script that applies labels from the config (NODE-02), and an operational runbook documenting the scheme and how to use it (NODE-03).

This phase creates no Kubernetes manifests and makes no Flux changes. Output is a script, a config file, and documentation that an operator runs once against the cluster before Phase 2 scheduling constraints are applied.

## Context

- @.planning/phases/01-node-labeling/01-CONTEXT.md — locked decisions and discretion areas
- @.planning/phases/01-node-labeling/01-RESEARCH.md — architecture patterns, pitfalls, code examples
- @docs/sso/ — existing docs style to match for node-labeling.md

## Must-Haves

Goal: Node roles are defined, documented, and the cluster can be labeled with a single script.

- `scripts/node-roles.yaml` exists with all three roles (infra, apps, runners) defined using placeholder node names
- `scripts/apply-node-labels.sh` is executable (`chmod +x`, git mode `100755`), idempotent (`--overwrite`), config-driven, and produces a verification summary after applying labels
- Label keys use the format `node-role.infra=true`, `node-role.apps=true`, `node-role.runners=true` — separate keys per role, NOT comma-separated values — this is the only format compatible with Phase 2 `nodeSelector` and `nodeAffinity`
- `docs/node-labeling.md` documents the three roles, which workloads target which roles, and contains step-by-step runbook sections for first-time labeling, adding new nodes, relabeling, removing a role, and troubleshooting
- All three requirements NODE-01, NODE-02, NODE-03 are satisfied

---

## Task 1: Create Node Role Config File

<task type="auto" wave="1">
  <name>Task 1: Create scripts/node-roles.yaml</name>
  <files>scripts/node-roles.yaml</files>
  <action>
Create the directory `scripts/` at the repo root (it does not yet exist). Create `scripts/node-roles.yaml` as the source-of-truth config for node-to-role mapping.

**Config format decisions (Claude's discretion, applied here):**
- Use YAML (not JSON) — matches repo dominant format
- Each role is listed as a separate entry under a node's `roles` array
- Placeholder node names used — operator must populate with actual `kubectl get nodes` output before running script
- Include a comment block explaining this requirement

**File content:**

```yaml
# Node role assignments for k3s-cluster
#
# BEFORE RUNNING apply-node-labels.sh:
#   Replace placeholder node names with actual cluster node names.
#   Run: kubectl get nodes -o custom-columns=NAME:.metadata.name
#
# Role definitions:
#   infra   — Cluster services: Prometheus, Grafana, Loki, OpenTelemetry,
#              Keycloak SSO, MinIO storage
#   apps    — Developer-facing services: Forgejo, Harbor, DevPI
#   runners — GitHub Actions runners (ARC runner scale sets)
#
# Nodes may have multiple roles. A node with both infra and apps roles
# receives both node-role.infra=true and node-role.apps=true labels.
#
# Runner guidance:
#   4-node cluster  → 1 runner node
#   5-6 node cluster → 2 runner nodes

nodes:
  - name: node-01          # Replace with: kubectl get nodes output
    roles:
      - infra
      - apps
  - name: node-02          # Replace with: kubectl get nodes output
    roles:
      - apps
  - name: node-03          # Replace with: kubectl get nodes output
    roles:
      - infra
  - name: node-04          # Replace with: kubectl get nodes output
    roles:
      - runners
```

This config shows a 4-node cluster with node-04 as the dedicated runner node. It demonstrates all three roles and the dual-role (infra + apps) pattern. The operator replaces the placeholder names.
  </action>
  <verify>
    <automated>test -f scripts/node-roles.yaml && grep -q "node-role.infra\|infra" scripts/node-roles.yaml && grep -q "runners" scripts/node-roles.yaml && echo "PASS: node-roles.yaml exists with all three roles"</automated>
  </verify>
  <done>
    `scripts/node-roles.yaml` exists with all three roles (infra, apps, runners) defined, placeholder node names, and instructional comments. File is valid YAML.
  </done>
</task>

---

## Task 2: Create the Label Application Script

<task type="auto" wave="2">
  <name>Task 2: Create scripts/apply-node-labels.sh</name>
  <files>scripts/apply-node-labels.sh</files>
  <action>
Create `scripts/apply-node-labels.sh` as an executable Bash script. Set the execute bit immediately: `chmod +x scripts/apply-node-labels.sh`. Verify git will track it as executable: `git ls-files --stage scripts/apply-node-labels.sh` should show mode `100755` (after `git add`).

**Key implementation requirements from RESEARCH.md:**

1. **Shebang and safety:** `#!/usr/bin/env bash` + `set -euo pipefail`
2. **Pre-flight checks (in order):**
   - Check `kubectl` is available — print install URL on failure, exit 1
   - Check `yq` is available — print `brew install yq` install instruction on failure, exit 1
   - Check yq version is v4+ — `yq --version` should produce a version >= 4; print clear error with install instruction if v3 detected
   - Check cluster connectivity via `kubectl cluster-info >/dev/null 2>&1` — print "Check KUBECONFIG" on failure, exit 1
3. **Config file argument:** Default config path is `${SCRIPT_DIR}/node-roles.yaml`. Accept optional first argument as override: `CONFIG_FILE="${1:-${SCRIPT_DIR}/node-roles.yaml}"`
4. **Dry-run mode:** Controlled by env variable `DRY_RUN=true` (not a CLI flag). When set, print `[DRY RUN]` prefix and skip actual `kubectl label` calls.
5. **Label application loop:**
   - Iterate nodes using `yq '.nodes | length'` for count, then index into each node
   - For each node, get its name with `yq ".nodes[$i].name"`
   - For each role in the node's roles array, apply label `node-role.${ROLE}=true --overwrite`
   - **CRITICAL:** Before labeling, check if the node exists: `kubectl get node "$NODE_NAME" >/dev/null 2>&1`. If node not found, print `WARNING: Node '$NODE_NAME' not found in cluster — skipping` and continue (do NOT hard-fail the entire run)
   - Print `  Applied: $NODE_NAME -> node-role.$ROLE=true` for each successful label
6. **Verification summary after all labels applied** (using custom-columns for clean tabular output):
   ```bash
   kubectl get nodes -o custom-columns=\
   'NAME:.metadata.name,INFRA:.metadata.labels.node-role\.infra,APPS:.metadata.labels.node-role\.apps,RUNNERS:.metadata.labels.node-role\.runners'
   ```
7. **Script header comment block** (the "usage in script header" location from CONTEXT.md):
   ```
   # apply-node-labels.sh
   # Applies node-role labels to k3s cluster nodes from a YAML config file.
   #
   # Usage:
   #   ./scripts/apply-node-labels.sh                          # uses scripts/node-roles.yaml
   #   ./scripts/apply-node-labels.sh /path/to/custom.yaml    # custom config
   #   DRY_RUN=true ./scripts/apply-node-labels.sh             # preview without applying
   #
   # Idempotent: safe to run multiple times (uses --overwrite).
   # Requires: kubectl (cluster access), yq v4+
   ```

**Anti-patterns to avoid (from RESEARCH.md):**
- Do NOT use comma-separated label values (`node-role=infra,apps`) — Phase 2 nodeSelector cannot match them
- Do NOT hardcode node names in the script — config file is the only source of node names
- Do NOT skip `--overwrite` on any label apply call
- Do NOT use yq v3 syntax (`yq r file.yaml path`) — use v4 syntax (`yq '.path' file.yaml`)

After creating the file, run `chmod +x scripts/apply-node-labels.sh` and `git add scripts/apply-node-labels.sh` to ensure the execute bit is tracked by git.
  </action>
  <verify>
    <automated>test -x scripts/apply-node-labels.sh && grep -q "set -euo pipefail" scripts/apply-node-labels.sh && grep -q "\-\-overwrite" scripts/apply-node-labels.sh && grep -q "DRY_RUN" scripts/apply-node-labels.sh && grep -q "node-role\." scripts/apply-node-labels.sh && grep -q "node-role\.infra" scripts/apply-node-labels.sh && bash -n scripts/apply-node-labels.sh && echo "PASS: script exists, is executable, and passes bash syntax check"</automated>
  </verify>
  <done>
    `scripts/apply-node-labels.sh` exists, is executable, passes `bash -n` syntax check, uses `--overwrite`, uses `DRY_RUN` env var for dry-run mode, applies separate boolean labels per role (`node-role.infra=true` etc.), checks for missing nodes with a warning rather than hard-failing, and prints a verification summary table after applying.
  </done>
</task>

---

## Task 3: Create the Operational Runbook

<task type="auto" wave="3">
  <name>Task 3: Create docs/node-labeling.md</name>
  <files>docs/node-labeling.md</files>
  <action>
Create `docs/node-labeling.md` as an operational runbook. Match the style of existing docs in `docs/sso/` — overview, prerequisites, numbered steps with commands, troubleshooting sections. This is the "detailed guide" documentation location from CONTEXT.md.

**Required sections and content:**

### Overview
Brief explanation: node roles enable workload scheduling in Phase 2 and Phase 3. Three roles exist. Labels are applied imperatively (not via GitOps). The config file is the source of truth.

### Node Roles
Table with three columns: Role, Label Applied, Workloads Targeted.

| Role | Label Applied | Workloads Targeted |
|------|--------------|-------------------|
| infra | `node-role.infra=true` | Prometheus, Grafana, Loki, OpenTelemetry, Keycloak SSO, MinIO |
| apps | `node-role.apps=true` | Forgejo, Harbor, DevPI |
| runners | `node-role.runners=true` | GitHub Actions ARC runner scale sets |

Include a note: nodes can have multiple roles (both `node-role.infra=true` and `node-role.apps=true` on the same node). This is intentional for clusters with 4-6 nodes.

**Runner node guidance rule** (from RESEARCH.md open question):
- 4-node cluster: 1 runner-dedicated node
- 5-6 node cluster: 2 runner-dedicated nodes

### Prerequisites
- `kubectl` with cluster access (verify with `kubectl get nodes`)
- `yq` v4+ installed (`brew install yq` on macOS; see https://github.com/mikefarah/yq/releases for ARM64 Linux)
- Repository cloned locally

### Applying Labels (First Time)
Step 1: Get actual node names from the cluster:
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name
```
Step 2: Edit `scripts/node-roles.yaml` — replace placeholder node names with actual names from step 1. Assign roles based on the role table above.

Step 3: Preview changes without applying (dry run):
```bash
DRY_RUN=true ./scripts/apply-node-labels.sh
```

Step 4: Apply labels:
```bash
./scripts/apply-node-labels.sh
```

Step 5: Verify — the script prints a summary table automatically after applying. To re-check at any time:
```bash
kubectl get nodes -o custom-columns='NAME:.metadata.name,INFRA:.metadata.labels.node-role\.infra,APPS:.metadata.labels.node-role\.apps,RUNNERS:.metadata.labels.node-role\.runners'
```

### Adding a New Node
1. Add the node's hostname to `scripts/node-roles.yaml` with appropriate roles
2. Run `./scripts/apply-node-labels.sh` (idempotent — existing nodes are not affected)

### Relabeling a Node (Changing Roles)
1. Update the node's roles in `scripts/node-roles.yaml`
2. Run `./scripts/apply-node-labels.sh` — `--overwrite` updates existing labels
3. If a role was REMOVED, remove the old label manually:
```bash
kubectl label node NODE_NAME node-role.ROLE-
```
(Note: the trailing `-` removes the label.)

### Removing a Role from a Node
Manual step required (the script only adds/overwrites, not removes):
```bash
kubectl label node NODE_NAME node-role.infra-
# or
kubectl label node NODE_NAME node-role.apps-
# or
kubectl label node NODE_NAME node-role.runners-
```
Then update `scripts/node-roles.yaml` to remove the role from that node.

### Troubleshooting

**`yq: command not found`**
Install yq v4: `brew install yq` (macOS) or download binary from https://github.com/mikefarah/yq/releases (ARM64: `yq_linux_arm64`)

**`yq` commands produce empty output or errors about unknown flags**
You likely have yq v3. The script requires v4. Check: `yq --version`. Install v4 via brew or the releases page above.

**`Error from server (NotFound)` for a node**
The node name in `scripts/node-roles.yaml` doesn't match the cluster. Run `kubectl get nodes` to get the exact registered name (may be FQDN or IP). The script prints a WARNING and continues — other nodes are still labeled.

**Cannot reach cluster / KUBECONFIG errors**
Verify: `kubectl cluster-info`. Check your KUBECONFIG environment variable or `~/.kube/config`. For k3s: copy `/etc/rancher/k3s/k3s.yaml` from the server node to your workstation.

**Script returns `permission denied`**
Set execute bit: `chmod +x scripts/apply-node-labels.sh`

**Scheduled workloads don't land on expected nodes after Phase 2**
Verify labels were applied: use the verification command in "Applying Labels" step 5. Ensure Phase 2 `nodeSelector` keys match exactly: `node-role.infra`, `node-role.apps`, `node-role.runners` (the dot-separated format, not slash-separated).

The runbook should be clear, concise, and use fenced code blocks for all commands. Match the tone and depth of existing docs in this repo.
  </action>
  <verify>
    <automated>test -f docs/node-labeling.md && grep -q "node-role.infra" docs/node-labeling.md && grep -q "node-role.apps" docs/node-labeling.md && grep -q "node-role.runners" docs/node-labeling.md && grep -q "Troubleshooting" docs/node-labeling.md && grep -q "apply-node-labels.sh" docs/node-labeling.md && grep -q "node-roles.yaml" docs/node-labeling.md && echo "PASS: runbook exists with all required sections and content"</automated>
  </verify>
  <done>
    `docs/node-labeling.md` exists and contains: role table with all three roles and their workload targets, prerequisites, first-time labeling steps referencing both `scripts/node-roles.yaml` and `scripts/apply-node-labels.sh`, sections for adding a new node, relabeling, removing a role, and troubleshooting common errors. Label key format (`node-role.infra=true`) is consistent throughout.
  </done>
</task>

---

## Verification Criteria

After all three tasks complete, verify:

1. `scripts/node-roles.yaml` — valid YAML with three roles (infra, apps, runners), placeholder nodes, explanatory comments
2. `scripts/apply-node-labels.sh` — executable, passes `bash -n` syntax check, contains `--overwrite`, `DRY_RUN`, `node-role.infra/apps/runners`, pre-flight checks, node-not-found warning, verification summary
3. `docs/node-labeling.md` — contains all required sections, references both script and config, uses correct label key format throughout

**Phase 1 success:** All three requirements NODE-01, NODE-02, NODE-03 are satisfied. Phase 2 can now reference `node-role.infra`, `node-role.apps`, and `node-role.runners` label keys in `nodeSelector` and `nodeAffinity` blocks.

**Final check command:**
```bash
test -f scripts/node-roles.yaml && \
test -x scripts/apply-node-labels.sh && \
bash -n scripts/apply-node-labels.sh && \
test -f docs/node-labeling.md && \
echo "Phase 1 complete — all artifacts present"
```
