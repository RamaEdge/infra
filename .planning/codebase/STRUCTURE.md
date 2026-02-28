# Codebase Structure

**Analysis Date:** 2026-02-28

## Directory Layout

```
infra/
├── clusters/                                    # Cluster-specific configurations
│   └── k3s-cluster/                            # k3s cluster deployment (single cluster)
│       ├── kustomization.yaml                  # Top-level orchestrator
│       ├── apps/                               # Application deployments
│       │   ├── actions-runner-controller/      # GitHub Actions runners
│       │   ├── devpi/                          # Python package index
│       │   ├── forgejo/                        # Git hosting (Gitea fork)
│       │   ├── harbor/                         # Container registry
│       │   ├── keycloak/                       # Identity & Access Management (SSO)
│       │   ├── kube-prometheus-stack/          # Prometheus + Grafana
│       │   ├── loki/                           # Log aggregation
│       │   ├── minio/                          # Object storage tenant
│       │   ├── minio-operator/                 # MinIO operator
│       │   ├── monitoring-config/              # Cross-app monitoring rules
│       │   └── opentelemetry-collector/        # Telemetry collection
│       └── flux-system/                        # Flux CD core configuration
│           ├── kustomization.yaml              # Flux system orchestration
│           ├── *-helmrepository.yaml           # Helm chart sources
│           └── *-kustomization.yaml            # Kustomization resources
├── docs/                                       # Documentation
│   ├── sso/                                    # SSO integration guides
│   └── filesystem-corruption-*.md              # Operational guides
├── .planning/                                  # GSD planning directory
├── README.md                                   # Main documentation
├── DEPLOYMENT.md                               # Deployment guide
└── SETUP_COMMANDS.md                           # Setup reference
```

## Directory Purposes

**clusters/**
- Purpose: Cluster-specific infrastructure as code
- Contains: Complete deployment manifests for k3s cluster
- Organization: One subdirectory per cluster (currently `k3s-cluster` only)

**clusters/k3s-cluster/**
- Purpose: Root orchestration for k3s cluster deployments
- Contains: Top-level kustomization and flux-system bootstrap configuration
- Key files: `kustomization.yaml` (entry point)

**clusters/k3s-cluster/apps/**
- Purpose: Individual application/service deployments
- Contains: One directory per application with Helm-based deployment
- Organization: Each app has `kustomization.yaml`, `helmrelease.yaml`, namespace/secret definitions
- Pattern: Namespace isolation - each app typically in dedicated Kubernetes namespace

**clusters/k3s-cluster/apps/{app-name}/**
- Purpose: Deploy single application with all dependencies
- Key files:
  - `kustomization.yaml`: Compose resources for this app
  - `helmrelease.yaml`: Helm chart deployment with values
  - `namespace.yaml`: Kubernetes namespace definition
  - `{dependency}-helmrelease.yaml`: Dependent services (databases, caches)
  - Other YAML: Custom Kubernetes resources, ConfigMaps, ServiceMonitors

**clusters/k3s-cluster/apps/actions-runner-controller/**
- Purpose: GitHub Actions runner scaling
- Contains: Operator HelmRelease, multiple runner scale sets (modbus, opcua, claude, code-quality, dependabot)
- Pattern: Operator-based deployment with multiple RunnerScaleSet configurations

**clusters/k3s-cluster/apps/harbor/**
- Purpose: Container registry with image scanning
- Contains: Harbor HelmRelease, Redis service for caching, namespace
- Storage: Longhorn volumes (200Gi registry, 5Gi trivy, 1Gi jobservice, 1Gi database)
- Dependencies: Redis (external), PostgreSQL (internal to Harbor)

**clusters/k3s-cluster/apps/keycloak/**
- Purpose: Identity and Access Management (SSO provider)
- Contains: Keycloak HelmRelease, dedicated PostgreSQL instance
- Used by: Forgejo, MinIO, Grafana, Harbor (via OIDC)
- Hostname: `auth.theedgeworks.ai`

**clusters/k3s-cluster/apps/forgejo/**
- Purpose: Git repository hosting (Gitea fork)
- Contains: Forgejo HelmRelease, PostgreSQL instance
- Storage: Longhorn 200Gi persistent volume
- Integration: OIDC with Keycloak realm `theedgeworks`
- Hostname: `code.theedgeworks.ai`

**clusters/k3s-cluster/apps/kube-prometheus-stack/**
- Purpose: Prometheus metrics and Grafana dashboards
- Contains: HelmRelease, custom dashboard ConfigMaps (harbor, nginx, longhorn, metallb)
- Dashboards: Pre-built dashboard definitions for cluster monitoring
- Namespace: `monitoring`

**clusters/k3s-cluster/apps/monitoring-config/**
- Purpose: Cross-application monitoring configuration
- Contains: ServiceMonitor and PrometheusRule resources for all apps
- Pattern: Decoupled from app definitions - centralized monitoring rules
- Files: One `servicemonitor-{app}.yaml` and `prometheusrule-{app}.yaml` per monitored service

**clusters/k3s-cluster/apps/loki/**
- Purpose: Log aggregation and storage
- Contains: Loki HelmRelease (single binary mode)
- Storage: Longhorn 200Gi persistent volume
- Retention: 30 days (720h)

**clusters/k3s-cluster/apps/minio/**
- Purpose: Object storage tenant instance
- Contains: MinIO Tenant resource (not Helm chart), ingress
- Dependencies: Managed by minio-operator
- Namespace: `minio-tenant`

**clusters/k3s-cluster/apps/minio-operator/**
- Purpose: Manages MinIO tenant lifecycle
- Contains: MinIO Operator HelmRelease
- Namespace: `minio-operator`

**clusters/k3s-cluster/apps/devpi/**
- Purpose: Python package index
- Contains: DevPI HelmRelease and configuration

**clusters/k3s-cluster/apps/opentelemetry-collector/**
- Purpose: Collect and forward telemetry data
- Contains: OpenTelemetry Collector HelmRelease

**clusters/k3s-cluster/flux-system/**
- Purpose: Flux CD core configuration and Helm repository registry
- Contains: HelmRepository resources, top-level Kustomization for monitoring config
- Key files:
  - `kustomization.yaml`: Includes all HelmRepository registrations and monitoring config
  - `*-helmrepository.yaml`: Registers external Helm chart sources
  - `*-kustomization.yaml`: Manages dependent resources (e.g., MinIO tenant waits for operator)

**docs/**
- Purpose: Operational and configuration documentation
- Contains: SSO setup guides, troubleshooting, operational procedures
- Subdirectories: `sso/` for identity provider configurations

**.planning/**
- Purpose: GSD (GitHub Source Design) planning and analysis
- Contains: Codebase analysis documents (ARCHITECTURE.md, STRUCTURE.md, etc.)

## Key File Locations

**Entry Points:**
- `clusters/k3s-cluster/kustomization.yaml`: Top-level Kubernetes resource orchestrator
- `clusters/k3s-cluster/flux-system/kustomization.yaml`: Flux system initialization and Helm registry setup
- `README.md`: Project overview and bootstrap instructions

**Configuration:**
- `clusters/k3s-cluster/apps/{app-name}/helmrelease.yaml`: Primary application configuration via Helm values
- `clusters/k3s-cluster/apps/{app-name}/kustomization.yaml`: Resource composition for each app
- `clusters/k3s-cluster/flux-system/*-helmrepository.yaml`: External Helm chart source declarations

**Core Logic:**
- `clusters/k3s-cluster/apps/harbor/helmrelease.yaml`: Registry service with full configuration
- `clusters/k3s-cluster/apps/keycloak/helmrelease.yaml`: Identity provider setup
- `clusters/k3s-cluster/apps/kube-prometheus-stack/helmrelease.yaml`: Observability platform

**Testing/Verification:**
- `DEPLOYMENT.md`: Step-by-step deployment verification
- `README.md`: Troubleshooting section with diagnostic commands

## Naming Conventions

**Files:**
- `kustomization.yaml`: Kustomize entry point for each directory level
- `helmrelease.yaml`: Primary application Helm deployment
- `{service}-helmrelease.yaml`: Dependency services (e.g., `postgres-helmrelease.yaml`, `redis.yaml`)
- `namespace.yaml`: Kubernetes namespace definition
- `{resource-type}-{service}.yaml`: Custom resources (e.g., `prometheusrule-harbor.yaml`, `servicemonitor-nginx-ingress.yaml`)
- `*-helmrepository.yaml`: External Helm chart source registry

**Directories:**
- `clusters/`: Multi-cluster support structure (extensible for future clusters)
- `apps/`: Application deployment modules
- Lowercase, hyphenated app names: `actions-runner-controller`, `kube-prometheus-stack`
- Short descriptive names matching Kubernetes official names where possible

**Kubernetes Resources:**
- Metadata namespace field: `flux-system` for HelmRepository and central HelmRelease resources
- Target namespaces: Per-app namespaces (e.g., `harbor`, `keycloak`, `forgejo`, `minio-tenant`, `monitoring`)
- Labels: Follow Kubernetes standard labels where applicable

## Where to Add New Code

**New Application Deployment:**
1. Create directory: `clusters/k3s-cluster/apps/{app-name}/`
2. Add namespace definition: `clusters/k3s-cluster/apps/{app-name}/namespace.yaml`
3. Add HelmRelease: `clusters/k3s-cluster/apps/{app-name}/helmrelease.yaml`
   - Reference chart from appropriate HelmRepository in `flux-system/`
   - Set targetNamespace to `{app-name}`
   - Include install/upgrade remediation: `retries: 3`
   - Add database/cache dependencies if needed: `{service}-helmrelease.yaml`
4. Add kustomization: `clusters/k3s-cluster/apps/{app-name}/kustomization.yaml`
   - Include all YAML resources for this app
5. Register in parent: Add resource to `clusters/k3s-cluster/kustomization.yaml`
6. Register HelmRepository if new: Add to `clusters/k3s-cluster/flux-system/kustomization.yaml`

**New Helm Repository Source:**
1. Create file: `clusters/k3s-cluster/flux-system/{provider}-helmrepository.yaml`
2. Define HelmRepository resource with:
   - Chart provider URL (HTTP or OCI)
   - Interval for periodic index refresh
   - Authentication if private repository
3. Register in flux-system kustomization: `clusters/k3s-cluster/flux-system/kustomization.yaml`

**Monitoring Configuration:**
1. Create ServiceMonitor: `clusters/k3s-cluster/apps/monitoring-config/servicemonitor-{app}.yaml`
   - Define scrape endpoints for Prometheus
   - Match pod labels for discovery
2. Create PrometheusRule: `clusters/k3s-cluster/apps/monitoring-config/prometheusrule-{app}.yaml`
   - Define alert conditions and thresholds
3. Register in kustomization: `clusters/k3s-cluster/apps/monitoring-config/kustomization.yaml`

**New Kubernetes Secret:**
- Create manually (NOT in Git): `kubectl create secret [type] [name] -n [namespace] --from-literal=key=value`
- Reference in HelmRelease values: `valueFrom.secretKeyRef` for environment variables or volume mounts
- Document creation process in `README.md` or app-specific `README.md`

## Special Directories

**clusters/k3s-cluster/flux-system/:**
- Purpose: Bootstrap Flux CD and register Helm sources
- Generated: No (manual YAML definitions)
- Committed: Yes (contains declarative configuration)
- Special: Processed first during cluster bootstrap; defines all external Helm chart sources

**.planning/**
- Purpose: GSD analysis and planning documents
- Generated: Yes (by GSD tooling)
- Committed: Yes (planning documents are tracked)
- Special: Referenced by other GSD commands for implementation guidance

**docs/sso/**
- Purpose: Identity provider integration documentation
- Generated: No (manual documentation)
- Committed: Yes
- Special: Operational guides for configuring Keycloak clients and SSO integrations

---

*Structure analysis: 2026-02-28*
