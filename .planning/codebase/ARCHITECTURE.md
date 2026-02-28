# Architecture

**Analysis Date:** 2026-02-28

## Pattern Overview

**Overall:** GitOps with Flux CD - Declarative Infrastructure as Code

**Key Characteristics:**
- Kubernetes-native, GitOps-driven deployment using Flux CD
- Cluster-centric architecture with Helm charts as primary deployment unit
- Namespace isolation per application/service
- HelmRelease CRDs manage Helm chart deployments with dependency ordering
- Kustomization resources compose and orchestrate multiple Helm releases
- Secret references for sensitive data (not stored in Git)
- Storage abstraction via Longhorn persistent volumes

## Layers

**Source Control Layer:**
- Purpose: Manage external Helm chart repositories and Git sources
- Location: `clusters/k3s-cluster/flux-system/`
- Contains: HelmRepository resources, GitRepository declarations
- Depends on: Upstream Helm registries (Bitnami, Grafana, Harbor, etc.)
- Used by: HelmRelease resources reference these sources

**Application Deployment Layer:**
- Purpose: Define and deploy individual applications as Helm releases
- Location: `clusters/k3s-cluster/apps/{app-name}/`
- Contains: HelmRelease manifests, namespace definitions, application-specific config
- Depends on: HelmRepository sources, Kubernetes secrets for credentials
- Used by: Top-level kustomization for orchestration

**Configuration & Monitoring Layer:**
- Purpose: Cross-cutting observability and monitoring configuration
- Location: `clusters/k3s-cluster/apps/monitoring-config/`
- Contains: PrometheusRule, ServiceMonitor, PodMonitor definitions
- Depends on: Kube-prometheus-stack for Prometheus/Grafana
- Used by: Prometheus for scraping and alerting rules

**Infrastructure Foundation Layer:**
- Purpose: Core cluster infrastructure (not managed by this repo)
- Location: Deployed via separate `infra-core` repository
- Contains: MetalLB (load balancer), Longhorn (storage), Flux components
- Deployed first: Bootstrap sequence requires `infra-core` before `infra`

## Data Flow

**Deployment Sequence:**

1. **Git Push** → Developer pushes changes to `ramaedge/infra` repository
2. **Flux Reconciliation** → Flux controller syncs repository at specified intervals
3. **GitRepository Fetch** → Flux reads Git repository contents
4. **Kustomization Build** → Flux builds Kustomization resources from YAML
5. **HelmRepository Resolution** → Flux resolves Helm charts from registered repositories
6. **HelmRelease Installation** → Helm Operator applies charts with specified values
7. **Dependency Ordering** → `dependsOn` directives enforce deployment order (e.g., database before application)
8. **Secret Injection** → Applications reference Kubernetes secrets for credentials
9. **Ingress Configuration** → Nginx ingress controller creates routes for applications
10. **Storage Mounting** → Longhorn provisions and mounts persistent volumes

**Example Flow - Harbor Deployment:**
1. `clusters/k3s-cluster/kustomization.yaml` includes `apps/harbor`
2. `apps/harbor/kustomization.yaml` includes `helmrelease.yaml` and `redis.yaml`
3. HelmRelease references `harbor` HelmRepository defined in `flux-system/harbor-helmrepository.yaml`
4. Harbor Helm chart deployed with Longhorn storage for registry, jobservice, trivy, database
5. Redis deployed as separate service for Harbor caching
6. Ingress created at `harbor.theedgeworks.ai` with TLS from `harbor-tls` secret
7. ServiceMonitor created in `monitoring-config/` for Prometheus scraping

**State Management:**
- Desired state: Stored in Git repository YAML manifests
- Current state: Tracked by Flux controllers on Kubernetes cluster
- Reconciliation: Flux continuously reconciles current state to desired state
- Secrets: Managed outside Git (stored directly on cluster), referenced by name

## Key Abstractions

**HelmRelease:**
- Purpose: Declarative Helm chart deployment with Flux management
- Examples: `apps/harbor/helmrelease.yaml`, `apps/keycloak/helmrelease.yaml`, `apps/forgejo/helmrelease.yaml`
- Pattern: Each HelmRelease specifies chart version, values overrides, installation/upgrade strategies, and dependencies

**Kustomization:**
- Purpose: Compose multiple Kubernetes resources with dependency management
- Examples: `clusters/k3s-cluster/kustomization.yaml` (top-level), `apps/*/kustomization.yaml` (per-app)
- Pattern: Resources list explicitly controls deployment order; namespace isolation via kustomization namespace field

**HelmRepository:**
- Purpose: External Helm chart source registration
- Examples: `flux-system/harbor-helmrepository.yaml`, `flux-system/bitnami-helmrepository.yaml`, `flux-system/grafana-helmrepository.yaml`
- Pattern: Each chart source declares interval, URL, authentication if needed; type field distinguishes OCI vs HTTP

**PrometheusRule & ServiceMonitor:**
- Purpose: Configuration for Prometheus metrics collection and alerting
- Examples: `monitoring-config/prometheusrule-harbor.yaml`, `monitoring-config/servicemonitor-harbor.yaml`
- Pattern: ServiceMonitor defines scrape targets and intervals; PrometheusRule defines alert conditions and thresholds

## Entry Points

**Cluster Bootstrap:**
- Location: `clusters/k3s-cluster/kustomization.yaml`
- Triggers: Flux watches this path and reconciles on changes
- Responsibilities: Includes all core namespaces and applications; orchestrates deployment order

**Flux System Configuration:**
- Location: `clusters/k3s-cluster/flux-system/kustomization.yaml`
- Triggers: Bootstrapped first during cluster setup
- Responsibilities: Registers Helm repositories, configures Kustomization resources for application deployments

**Application Deployment:**
- Location: `clusters/k3s-cluster/apps/{app-name}/kustomization.yaml`
- Triggers: Included by parent kustomization or monitored independently
- Responsibilities: Defines application-specific resources (namespace, HelmRelease, custom config)

**GitOps Bootstrap Command:**
- Triggers: Initial cluster setup
- Command: `flux bootstrap github --owner=ramaedge --repository=infra --path=./clusters/k3s-cluster`
- Responsibilities: Installs Flux components and sets up initial GitRepository pointing to infra repository

## Error Handling

**Strategy:** Retry-based remediation with exponential backoff

**Patterns:**
- **Install Remediation:** HelmRelease includes `install.remediation.retries: 3` for installation failures
- **Upgrade Remediation:** HelmRelease includes `upgrade.remediation.retries: 3` for upgrade failures
- **Dependency Blocking:** If dependency (e.g., database) fails, dependent applications (e.g., Keycloak) remain in pending state
- **Namespace Pre-creation:** `createNamespace: false` in HelmRelease requires explicit namespace.yaml creation, preventing silent failures
- **Status Monitoring:** `flux get helmreleases` and `flux get kustomizations` expose reconciliation status

## Cross-Cutting Concerns

**Logging:**
- Centralized via Loki (log aggregation server) at `apps/loki/helmrelease.yaml`
- Deployed with single-binary mode, filesystem storage on Longhorn
- 30-day retention configured (720h)

**Validation:**
- Performed at Helm chart level (each chart includes CRD validation)
- Kustomize provides structural validation via JSON schema
- Pre-deployment: `kubectl apply --dry-run=client` pattern used by developers

**Authentication:**
- Keycloak deployed at `apps/keycloak/` for centralized SSO
- Applications configure OIDC integration: Forgejo, MinIO, Harbor, Grafana
- Database credentials stored in Kubernetes secrets, referenced by HelmRelease values
- TLS certificates stored as Kubernetes secrets (e.g., `harbor-tls`, `forgejo-tls`)

**Observability:**
- **Metrics:** Prometheus (via kube-prometheus-stack) scrapes targets defined by ServiceMonitor resources
- **Dashboards:** Grafana displays Prometheus metrics with preconfigured dashboards
- **Alerting:** PrometheusRule resources define alert conditions; alerts routed via AlertManager
- **Logs:** Loki aggregates container logs; Grafana queries Loki for log visualization

---

*Architecture analysis: 2026-02-28*
