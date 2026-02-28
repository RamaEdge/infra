# External Integrations

**Analysis Date:** 2026-02-28

## APIs & External Services

**GitHub:**
- GitHub Actions Runner Controller integration for self-hosted CI/CD
  - Integration: Actions Runner Controller (ARC) 0.13.1
  - Auth: GitHub Personal Access Token (stored in `arc-runner-set-secret`, `claude-runner-set-secret`)
  - Webhook: GitHub sends workflow events to trigger runners
  - Organization: ramaedge (https://github.com/ramaedge)

**Image Repositories:**
- GHCR (GitHub Container Registry) - Harbor component images
  - Images: ghcr.io/octohelm/harbor/* (v2.14.0)
  - Usage: All Harbor service components (core, portal, jobservice, registry, nginx, exporter, trivy-adapter)

- Quay.io - MinIO and related images
  - Images: quay.io/minio/minio, quay.io/minio/operator, quay.io/minio/console
  - Version: RELEASE.2025-04-08T15-41-24Z (MinIO)

- Docker Hub (public registries)
  - arm64v8/redis:7-alpine - Redis for Harbor
  - docker.io/busybox:1.32 - Keycloak database checker

- Harbor internal registry (container deployment)
  - Images stored for: actions-runner-claude, actions-runner (internal builds)

**Trivy Vulnerability Scanner (Harbor):**
- Primary: ghcr.io/aquasecurity/trivy-db
- Mirror: mirror.gcr.io/aquasec/trivy-db
- Java DB Primary: ghcr.io/aquasecurity/trivy-java-db
- Mirror: mirror.gcr.io/aquasec/trivy-java-db
- Configuration: `clusters/k3s-cluster/apps/harbor/helmrelease.yaml` (lines 174-180)

## Data Storage

**Databases:**

**PostgreSQL (Bitnami):**
- Keycloak Database
  - Service: `keycloak-postgresql.keycloak.svc.cluster.local:5432`
  - Username: keycloak
  - Database: keycloak
  - Credentials: Secret `keycloak-db-credentials`
  - Storage: 1Gi Longhorn PVC
  - Helm chart version: 18.1.13

- Forgejo Database
  - Service: `forgejo-postgresql.forgejo.svc.cluster.local:5432`
  - Username: forgejo
  - Database: forgejo
  - Credentials: Secret `forgejo-db-credentials`
  - Storage: 1Gi Longhorn PVC
  - Helm chart version: 18.1.13
  - Configuration file: `clusters/k3s-cluster/apps/forgejo/postgres-helmrelease.yaml`

**Cache/Session Store:**

**Redis:**
- Harbor Redis Cache
  - Service: `redis-service.harbor.svc.cluster.local:6379`
  - Image: arm64v8/redis:7-alpine
  - Storage: 1Gi Longhorn PVC
  - Configuration: `clusters/k3s-cluster/apps/harbor/redis.yaml`
  - Usage: Session store, job queue for Harbor

## File Storage

**Object Storage:**

**MinIO S3-Compatible:**
- Service URLs: https://storage.theedgeworks.ai (API), https://storage-console.theedgeworks.ai (Console)
- Tenant: minio-tenant
- Configuration: `clusters/k3s-cluster/apps/minio/tenant.yaml`
- Storage: 300Gi per server (3 servers, 2 volumes each = 1.8Ti total)
- StorageClass: Longhorn

**Harbor Registry Storage:**
- Backend: Filesystem at /storage
- Mounted from Longhorn PVC: 200Gi
- Handles image layers, artifacts, and Trivy vulnerability database

**Persistent Volumes (All backed by Longhorn):**
- Harbor registry: 200Gi
- Harbor jobservice: 1Gi
- Harbor trivy-db: 5Gi
- Harbor database: 1Gi
- Prometheus metrics: 500Gi
- Loki logs: 200Gi
- MinIO tenant: 300Gi per node (distributed)
- GitHub Actions runners: 5Gi ephemeral per runner

## Authentication & Identity

**OIDC Provider:**

**Keycloak:**
- Service: https://auth.theedgeworks.ai
- Realm: theedgeworks
- Database: PostgreSQL (keycloak-postgresql)
- Version: Helm chart 7.1.5 (codecentric)
- Admin credentials: Secret `keycloak-admin-credentials`
- Configuration: `clusters/k3s-cluster/apps/keycloak/helmrelease.yaml`

**OIDC Clients Configured:**

1. **Forgejo (Git Hosting)**
   - Provider: Keycloak OpenID Connect
   - Client ID: forgejo
   - Auto-discovery URL: https://auth.theedgeworks.ai/realms/theedgeworks/.well-known/openid-configuration
   - Credentials: Secret `forgejo-oidc-secret`
   - Configuration: `clusters/k3s-cluster/apps/forgejo/helmrelease.yaml` (lines 72-76)

2. **Grafana (Monitoring Dashboard)**
   - Provider: Keycloak Generic OAuth
   - Client ID: theedgeworks
   - Auth URL: https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/auth
   - Token URL: https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/token
   - User info URL: https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/userinfo
   - Logout URL: https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/logout
   - Credentials: Secret `keycloak-oidc` (environment-based)
   - Scopes: openid, profile, email
   - Attribute mappings: email, name, groups (for role-based access)
   - Configuration: `clusters/k3s-cluster/apps/kube-prometheus-stack/helmrelease.yaml` (lines 73-89)

## Monitoring & Observability

**Metrics Collection:**

**Prometheus:**
- Scrape targets: All Kubernetes metrics via ServiceMonitor resources
- Retention: 10 days (retentionSize: 450GB)
- Storage: 500Gi Longhorn PVC
- Version: Helm chart kube-prometheus-stack 80.6.0
- ServiceMonitor selectors: Cluster-wide (all namespaces)

**Visualization:**

**Grafana:**
- Dashboard server: https://monitor.theedgeworks.ai
- Authentication: Keycloak OIDC (required, login form disabled)
- Storage: 2Gi Longhorn PVC
- Data sources configured:
  - Prometheus (cluster-local metrics)
  - Loki (logs via http://loki.monitoring.svc.cluster.local:3100)
- Dashboards: Harbor, MetalLB, Longhorn, NGINX Ingress
- Version: Part of kube-prometheus-stack 80.6.0

**Log Aggregation:**

**Loki:**
- Service: http://loki.monitoring.svc.cluster.local:3100
- Deployment: SingleBinary (monolithic mode)
- Storage: Filesystem backend with 200Gi Longhorn PVC
- Retention: 720 hours (30 days)
- Schema: v13 (TSDB)
- Scraped by: OpenTelemetry Collector DaemonSet
- Version: Helm chart 6.52.0

**Log Collection:**

**OpenTelemetry Collector:**
- Deployment: DaemonSet mode
- Receivers:
  - Filelog: Reads /var/log/pods/ from all nodes
  - Formats supported: Docker, CRI-O, containerd
- Processors: memory_limiter, transform, resource, batch
- Exporters: Loki (http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push)
- Memory limit: 400Mi (spike limit 100Mi)
- Version: Helm chart 0.108.0

**ServiceMonitors:**
- Harbor: `clusters/k3s-cluster/apps/monitoring-config/servicemonitor-*`
- MetalLB: Prometheus scrape configured
- NGINX Ingress: Metrics endpoint monitoring
- Longhorn: Dashboard monitoring
- Loki: ServiceMonitor enabled in chart
- OpenTelemetry: ServiceMonitor enabled in chart

## CI/CD & Deployment

**Git-based Deployment:**

**Flux CD:**
- Bootstrap repository: infra-core (core infrastructure)
- GitOps repository: infra (applications)
- GitHub organization: ramaedge
- Branch: main
- Reconciliation: Automatic via Git webhooks
- Components:
  - helm-controller: Helm release management
  - kustomize-controller: Kustomization/overlay management
  - image-reflector-controller: Container image scanning
  - image-automation-controller: Automated image updates in Git

**Container Registry Integration:**

**Harbor Registry:**
- Registry URL: https://harbor.theedgeworks.ai
- Vulnerability scanning: Integrated Trivy adapter
- Image sources: GitHub Actions, internal builds
- Storage backend: Filesystem on Longhorn
- Version: 2.14.0 (octohelm ARM64-compatible images)

**GitHub Actions Runners:**

**Actions Runner Controller (ARC):**
- Operator version: 0.13.1
- Scale sets deployed: 4 (standard, code-quality, dependabot, claude)
- Additional custom runners: OPC/UA, Modbus
- GitHub integration: GitHub token in secrets
- GitHub org: ramaedge
- Auto-scaling:
  - Min runners: 0
  - Max runners: 10 per scale set
- Runner images: harbor.theedgeworks.ai/base/actions-runner-*
- Workspace storage: 5Gi ephemeral Longhorn PVC per runner
- Configuration: `clusters/k3s-cluster/apps/actions-runner-controller/`

## Webhooks & Callbacks

**Incoming:**

**GitHub Actions Events:**
- Triggered by: GitHub Actions workflows in ramaedge organization
- Handler: Actions Runner Controller listens for GitHub webhook events
- Route: GitHub → ARC operator → Runner scale set → Runner pod

**Flux CD GitOps:**
- Source: GitHub repository (infra, infra-core)
- Trigger: Git push to main branch
- Handler: Flux GitRepository source controller
- Reconciliation: Automatic (5m default interval)

**Outgoing:**

**Harbor Image Notifications:**
- Registry events: Image push/delete events
- Not explicitly configured for external webhooks (internal usage only)

**Log Export:**

**OpenTelemetry to Loki:**
- Collector runs on all nodes (DaemonSet)
- Exports: Filelog → transform → Loki API
- Endpoint: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push

## Environment Configuration

**Required Kubernetes Secrets:**

**TLS/Certificate Secrets:**
- `forgejo-tls` - TLS cert/key for code.theedgeworks.ai
- `keycloak-tls` - TLS cert/key for auth.theedgeworks.ai
- `monitor-tls` - TLS cert/key for monitor.theedgeworks.ai
- `harbor-tls` - TLS cert/key for harbor.theedgeworks.ai

**Database Credentials:**
- `keycloak-db-credentials` - PostgreSQL user password for Keycloak
- `forgejo-db-credentials` - PostgreSQL user password for Forgejo

**OIDC Secrets:**
- `forgejo-oidc-secret` - Keycloak client credentials for Forgejo
  - Keys: `key` (client ID), `secret` (client secret)
- `keycloak-oidc` - Keycloak OIDC for Grafana
  - Environment variable format: GRAFANA_AUTH_GENERIC_OAUTH_CLIENT_SECRET

**Admin Credentials:**
- `keycloak-admin-credentials` - Keycloak admin user/password
  - Keys: `username`, `password`
- `forgejo-admin-secret` - Forgejo initial admin account
  - Keys: `username`, `password`, `email`

**GitHub Integration:**
- `arc-runner-set-secret` - GitHub token for Actions Runner Controller
  - Key: `github_token`
- `claude-runner-set-secret` - GitHub token for Claude runner
  - Key: `github_token`

**Domain Configuration:**
- DNS must resolve:
  - `harbor.theedgeworks.ai` → MetalLB ingress
  - `code.theedgeworks.ai` → MetalLB ingress
  - `auth.theedgeworks.ai` → MetalLB ingress (special: 192.168.0.110)
  - `storage.theedgeworks.ai` → MetalLB ingress
  - `storage-console.theedgeworks.ai` → MetalLB ingress
  - `monitor.theedgeworks.ai` → MetalLB ingress

---

*Integration audit: 2026-02-28*
