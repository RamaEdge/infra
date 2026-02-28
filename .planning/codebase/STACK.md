# Technology Stack

**Analysis Date:** 2026-02-28

## Languages

**Primary:**
- YAML - Kubernetes manifests, Helm values, and GitOps configuration
- Bash - Deployment and setup scripts

**Configuration & Markup:**
- Markdown - Documentation

## Runtime

**Environment:**
- Kubernetes (k3s cluster) - ARM64-compatible lightweight Kubernetes
- Docker-compatible container runtime (CRI-O or containerd)

**Package Manager:**
- Helm 3.x - Kubernetes package management
- Flux CD 2.x - GitOps controller for declarative cluster management

## Frameworks & Core Infrastructure

**Container Orchestration:**
- Kubernetes (k3s) - Primary orchestration platform
- Flux CD - GitOps automation for cluster state management

**Storage:**
- Longhorn - Distributed block storage for Kubernetes persistent volumes
- MinIO Operator - Object storage management

**Load Balancing:**
- MetalLB - Bare-metal load balancer for k3s clusters

## Key Dependencies (Helm Charts)

**Version Pinning:**

### Application Management
- `flux/helm-controller` - Helm release operator
- `flux/kustomize-controller` - Kustomization operator
- `flux/image-reflector-controller` - Container image scanning
- `flux/image-automation-controller` - Automated image updates

### Container Registry
- Harbor 1.18.1 (ghcr.io/octohelm/harbor images) - Container image registry with vulnerability scanning
  - Components: core, portal, jobservice, registry, nginx, exporter, trivy-adapter
  - Port: 8443 (HTTPS)

### Git Hosting
- Forgejo 16.1.0 - Git repository hosting
  - URL: `code.theedgeworks.ai`
  - Based on Gitea fork

### Identity & Access Management
- Keycloak 7.1.5 (codecentric Helm chart) - OpenID Connect provider
  - URL: `auth.theedgeworks.ai`
  - Realm: `theedgeworks`

### Object Storage
- MinIO Operator 7.1.1 - S3-compatible object storage
  - Tenant image: quay.io/minio/minio:RELEASE.2025-04-08T15-41-24Z
  - Console: quay.io/minio/console:v7.1.1
  - URL: `storage.theedgeworks.ai`

### Monitoring & Observability
- Prometheus Community Stack 80.6.0
  - Prometheus - Metrics collection and storage (500Gi Longhorn PVC)
  - Grafana - Metrics visualization and dashboarding
    - URL: `monitor.theedgeworks.ai`
    - Keycloak OIDC authentication enabled
  - AlertManager - Alert routing and management
  - Node Exporter - Node metrics collection
  - ServiceMonitor CRDs for Prometheus scrape configuration

- Loki 6.52.0 (Grafana Helm chart) - Log aggregation
  - Deployment mode: SingleBinary
  - Storage: Longhorn filesystem backend (200Gi PVC)
  - Retention: 720 hours (30 days)

- OpenTelemetry Collector 0.108.0
  - Mode: DaemonSet for distributed log collection
  - Image: otel/opentelemetry-collector-contrib
  - Exports logs to Loki via filelog receiver

### Databases
- PostgreSQL 18.1.13 (Bitnami)
  - Keycloak instance: `keycloak-postgresql.keycloak.svc.cluster.local:5432`
  - Forgejo instance: `forgejo-postgresql.forgejo.svc.cluster.local:5432`
  - Storage: 1Gi Longhorn PVC per instance

- Redis 7-alpine (custom Deployment)
  - Harbor Redis: `redis-service.harbor.svc.cluster.local:6379`
  - Storage: 1Gi Longhorn PVC

### CI/CD & Automation
- Actions Runner Controller (GitHub) 0.13.1
  - Main runner: gha-runner-scale-set 0.13.1
  - Code quality runner: dedicated scale set
  - Dependabot runner: dedicated scale set
  - Claude-specific runner: dedicated scale set
  - OPC/UA runner: custom scale set
  - Modbus runner: custom scale set
  - Auto-scaling: 0-10 runners per scale set
  - Storage: 5Gi ephemeral Longhorn PVC per runner

### Ingress & Networking
- NGINX Ingress Controller (assumed, from chart references)
  - Handles TLS termination for all applications
  - Annotations for large payload support (Harbor uploads)

## Configuration Files

**Build & Deployment:**
- Flux CD manifests: `.planning/clusters/k3s-cluster/flux-system/`
- Helm repositories: Multiple (Prometheus Community, Bitnami, Grafana, Codecentric, MinIO, Forgejo, OpenTelemetry, Harbor)
- HelmRelease definitions: Per-application configuration in `.planning/clusters/k3s-cluster/apps/*/`
- Kustomization overlays: Per-namespace customization

**Environment Configuration:**
- Kubernetes Secrets (managed outside Git)
  - TLS certificates: `forgejo-tls`, `keycloak-tls`, `monitor-tls`, `harbor-tls`
  - Database credentials: `keycloak-db-credentials`, `forgejo-db-credentials`
  - OIDC secrets: `forgejo-oidc-secret`
  - Runner secrets: `arc-runner-set-secret`, GitHub tokens

## Platform Requirements

**Development/Deployment:**
- k3s cluster (ARM64 supported)
- Longhorn prerequisites: open-iscsi, nfs-common, iSCSI capable kernel
- Flux CLI for bootstrap and management
- kubectl for cluster interaction

**Production Deployment:**
- k3s cluster running on Kubernetes 1.24+
- Longhorn-compatible filesystem (ext4 or XFS)
- TLS certificates for ingress domains
- Domain names for services: `harbor.theedgeworks.ai`, `code.theedgeworks.ai`, `auth.theedgeworks.ai`, `storage.theedgeworks.ai`, `monitor.theedgeworks.ai`
- ARM64 node selector support for Harbor and MinIO
- 16GB+ RAM recommended for monitoring stack
- 500GB+ storage for Prometheus retention

## Architecture Patterns

**GitOps:**
- Flux CD manages all cluster state declaratively
- Configuration as Code in Git
- Automatic reconciliation of cluster state

**Multi-Tenancy:**
- Namespace isolation: `flux-system`, `monitoring`, `harbor`, `keycloak`, `forgejo`, `minio-tenant`, `actions-runner-system`, `arc-runners`
- Role-based access control (implicit via Keycloak OIDC)

**High Availability Considerations:**
- Single-replica deployments (optimized for edge/ARM)
- Longhorn distributed storage as resilience layer
- Ephemeral volumes for runner workloads

---

*Stack analysis: 2026-02-28*
