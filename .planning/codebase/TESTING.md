# Testing Patterns

**Analysis Date:** 2026-02-28

## Overview

This is a Kubernetes/Flux GitOps infrastructure-as-code repository. There is no application code (JavaScript, TypeScript, Python, etc.) and therefore no automated unit tests, integration tests, or test frameworks configured (Jest, Vitest, pytest, etc.).

**What exists instead:**
- Manual deployment verification procedures (documented in README.md)
- Kubernetes resource validation via `kubectl` commands
- Flux status monitoring and health checks
- Ad-hoc troubleshooting guides

## Manual Deployment Verification

The codebase includes documented manual verification procedures in `README.md` instead of automated tests.

**Flux Status Verification:**
```bash
# Check Flux components and health
kubectl get pods -n flux-system
flux get kustomizations -n flux-system
flux get sources git -n flux-system
```

**Application Deployment Verification:**
```bash
# Check individual application deployments
kubectl get pods -n harbor
kubectl get pods -n minio-tenant
kubectl get pods -n monitoring
kubectl get pods -n keycloak
kubectl get pods -n actions-runner-system
```

**Specific Component Checks:**
```bash
# Longhorn storage system
kubectl get pods -n longhorn-system

# Verify prerequisites on nodes
kubectl get nodes -o wide
```

## Validation Patterns

**Prerequisites Verification:**

For Longhorn (documented in README.md):
```bash
# Check iscsid is running
sudo systemctl status iscsid

# Check iSCSI tools available
which iscsiadm
iscsiadm --version

# Check NFS client installed
dpkg -l | grep nfs-common

# Check kernel modules
lsmod | grep iscsi
```

**Configuration Validation:**

Pre-deployment checks documented:
1. TLS certificates and keys for ingress must exist as Kubernetes secrets
2. Credentials must be created as Kubernetes secrets:
   - `ramaedge-tls-secret` (TLS certificate)
   - `minio-credentials` (MinIO admin credentials)
   - `harbor-db-credentials` (Harbor database credentials)
   - `keycloak-admin-credentials` (Keycloak admin credentials)
3. Required secrets for authentication:
   - `keycloak-oidc` (OIDC client secrets for Grafana)
   - `infra` (Git repository authentication)

## Environment Testing

**Tested Deployment Targets:**
- Kubernetes distribution: k3s (lightweight Kubernetes for ARM64/Raspberry Pi)
- Kubernetes version: 1.25+ (implied by Flux v2 CRD requirements)
- Architecture: ARM64 (explicitly tested on Raspberry Pi)
- OS: Raspberry Pi OS / Debian-based Linux

**Component Compatibility:**
- Most Helm charts use multi-architecture images (amd64 + arm64)
- ARM64 overrides documented for components without multi-arch support:
  - Harbor uses octohelm/harbor images from GHCR (ARM64 support)
  - Redis uses arm64v8/redis image
  - Loki, Prometheus, Grafana via Helm charts (multi-arch defaults)

## Troubleshooting as Testing

The codebase includes detailed troubleshooting sections that function as integration test guides in `README.md`.

**Flux Troubleshooting Validation:**
```bash
# Check Flux components running
kubectl get pods -n flux-system

# Examine GitRepository status
kubectl describe gitrepository -n flux-system

# Examine Kustomization status
kubectl describe kustomization -n flux-system

# View Flux controller logs
kubectl logs -n flux-system -l app=helm-controller
kubectl logs -n flux-system -l app=kustomize-controller
```

**Longhorn Troubleshooting Validation:**
```bash
# Verify Longhorn pods
kubectl get pods -n longhorn-system

# Check Longhorn manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager

# Verify prerequisites on nodes
ssh <node>
# Check: iscsid running, open-iscsi installed, nfs-common installed
```

## Configuration Testing

**Documented Test Cases:**

1. **Bootstrap Flow:**
   - Install Flux CLI
   - Install Flux components
   - Bootstrap infra-core repository first (MetalLB, Longhorn)
   - Add infra repository as second source

2. **Secret Creation Testing:**
   - Create TLS secret: `kubectl create secret tls ramaedge-tls-secret --cert=/path/to/cert.crt --key=/path/to/key.key`
   - Create MinIO secret: `kubectl create secret generic minio-credentials --from-literal=username=admin --from-literal=password=...`
   - Create Harbor DB secret: `kubectl create secret generic harbor-db-credentials --from-literal=username=harbor --from-literal=password=...`
   - Create Keycloak admin secret: Manual creation of `keycloak-admin-credentials`

3. **Path Validation:**
   - Kustomization paths must match repository structure
   - Common error: "Kustomization sync failures" if paths are wrong
   - Test with: `kubectl describe kustomization -n flux-system`

## Error Scenarios Documented

**Error: "no matches for kind Kustomization"**
- Cause: Flux CRDs not installed
- Test/Fix: Run `flux install` first

**Error: Longhorn pods in CrashLoopBackOff**
- Cause: Missing `open-iscsi` and `nfs-common` on nodes
- Test/Fix: Install packages and restart pods

**Error: GitRepository authentication errors**
- Cause: Secrets not created for private repositories
- Test/Fix: Create auth secret with `flux create secret git`

**Error: TLS/Certificate issues**
- Cause: TLS secret not created or incorrectly named
- Test: Verify secret exists: `kubectl get secret ramaedge-tls-secret`

## Monitoring as Testing

The monitoring stack (Prometheus, Loki, Grafana) serves as continuous testing:

**Prometheus Monitoring (`clusters/k3s-cluster/apps/kube-prometheus-stack/helmrelease.yaml`):**
- Scrapes metrics from all components
- 10-day retention window
- 450GB storage limit
- ServiceMonitors configured for all applications

**Log Aggregation Testing (`clusters/k3s-cluster/apps/opentelemetry-collector/helmrelease.yaml`):**
- OpenTelemetry collector as DaemonSet
- Collects logs from `/var/log/pods/`
- Parses CRI-O, containerd, and Docker log formats
- Exports to Loki for searching

**Grafana Dashboards for Visual Testing:**
- `dashboard-harbor.yaml` - Monitor Harbor components
- `dashboard-nginx-ingress.yaml` - Monitor Ingress controller
- `dashboard-longhorn.yaml` - Monitor storage system
- `dashboard-metallb.yaml` - Monitor load balancer

## Test Data / Fixtures

**Fixture Configuration (not committed, created manually):**
```bash
# TLS Certificate fixture
kubectl create secret tls ramaedge-tls-secret \
  --cert=/path/to/cert.crt \
  --key=/path/to/key.key

# MinIO test credentials
kubectl create secret generic minio-credentials \
  --from-literal=username=admin \
  --from-literal=password=RamaedgeMinio692#

# Harbor DB test credentials
kubectl create secret generic harbor-db-credentials \
  --from-literal=username=harbor \
  --from-literal=password=RamaedgeHarbor692#

# Keycloak admin credentials
kubectl create secret generic keycloak-admin-credentials \
  --from-literal=username=admin \
  --from-literal=password=<password>

# Keycloak OIDC client secret (for Grafana)
kubectl create secret generic keycloak-oidc \
  --from-literal=GRAFANA_AUTH_GENERIC_OAUTH_CLIENT_SECRET=<secret>
```

## Coverage & Gaps

**What is Tested:**
- Flux installation and bootstrapping (manual)
- Resource deployment order via dependsOn relationships
- Kubernetes CRD creation and updates
- Helm chart compatibility with ARM64
- Service discovery and networking (cross-namespace)
- Storage provisioning via Longhorn
- TLS/HTTPS configuration for ingress
- Monitoring stack health (Prometheus, Loki, Grafana)
- Authentication (Keycloak OIDC)

**What is NOT Tested:**
- Automated unit tests (not applicable to IaC)
- Automated integration tests (manual verification only)
- Application functionality (Harbor, MinIO, Keycloak - tested by upstream)
- Helm chart upgrades (tested manually during deployments)
- Failure recovery scenarios (documented but not automated)
- Performance/load testing (not applicable to infrastructure)

## Deployment Testing Checklist

From `README.md` - manual verification checklist:

```
Pre-deployment:
- [ ] Flux CLI installed
- [ ] k3s cluster running
- [ ] TLS certificates available
- [ ] Longhorn prerequisites installed on all nodes
  - [ ] open-iscsi
  - [ ] nfs-common
  - [ ] iscsid service running

Deployment:
- [ ] flux install completed
- [ ] infra-core bootstrapped first
- [ ] Required secrets created
- [ ] infra repository added as second source
- [ ] git changes pushed

Post-deployment:
- [ ] Flux pods running (kubectl get pods -n flux-system)
- [ ] Kustomizations synced (flux get kustomizations)
- [ ] Applications deployed (kubectl get pods -n {namespace})
- [ ] Longhorn pods running (kubectl get pods -n longhorn-system)
- [ ] Ingress working (HTTPS access to applications)
```

## Continuous Validation via Flux

**Flux Reconciliation as Testing:**
- Interval: 5m (most HelmReleases) to 1h (some repositories)
- Automatic remediation: retries: 3 on install/upgrade failures
- Automatic drift detection: Flux detects and reports configuration drift
- Status monitoring: `flux get kustomizations` shows sync status

**Test Commands for Each Component:**

```bash
# Monitor Flux reconciliation
flux get all -A

# Watch specific application deployment
kubectl rollout status deployment/harbor-core -n harbor
kubectl rollout status statefulset/prometheus -n monitoring

# Verify ingress is working
kubectl get ingress -A
kubectl describe ingress harbor-ingress

# Check for errors in pod logs
kubectl logs -n harbor -l app=harbor-core
kubectl logs -n monitoring -l app.kubernetes.io/name=loki
```

---

*Testing analysis: 2026-02-28*
