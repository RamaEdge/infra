# Codebase Concerns

**Analysis Date:** 2026-02-28

## Tech Debt

**Hardcoded Default Passwords:**
- Issue: Grafana admin password hardcoded to default value "prom-operator"
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/kube-prometheus-stack/helmrelease.yaml` (line 57)
- Impact: Weak security posture, default credentials exposed in version control
- Fix approach: Move to secret-based configuration with `envFromSecrets` or custom password generation; use Flux sealed secrets or external secret operators

**Container Image Pull Policy Inconsistency:**
- Issue: Some deployments use `imagePullPolicy: Always` while others rely on defaults, creating inconsistent cache behavior
- Files:
  - `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/actions-runner-controller/claude-scale-set-helmrelease.yaml` (line 44)
  - `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/devpi/deployment.yaml` (line 24)
- Impact: Unpredictable behavior; some pods may use stale local images while others always pull fresh; inconsistent across runner types
- Fix approach: Define cluster-wide policy in image pull defaults; use consistent `imagePullPolicy: IfNotPresent` for stable versions and `Always` only for active development images

**"Latest" Image Tag Usage:**
- Issue: Dependabot runner scale set uses `ghcr.io/actions/actions-runner:latest` instead of pinned version
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/actions-runner-controller/dependabot-runner-scale-set-helmrelease.yaml` (line 52)
- Impact: Non-deterministic deployments; breaking changes from upstream releases are silently applied; cannot reproduce issues reliably
- Fix approach: Pin all image tags to specific versions (e.g., `v2.319.0`); use dependabot or renovate bot to automatically update version pinning

**MinIO Release Date-Based Versioning:**
- Issue: MinIO uses release-date format `RELEASE.2025-04-08T15-41-24Z` which is opaque and hard to track
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/minio/tenant.yaml` (line 7)
- Impact: Difficult to identify which MinIO version is running; security patches may be missed; version history is obscured
- Fix approach: Document the semantic version equivalent; consider using MinIO's semantic version tags when available; maintain upgrade changelog

## Known Bugs

**Harbor Registry Permission Issues:**
- Symptoms: Harbor registry container may fail to write to storage due to permission mismatches between UID 10000 (container user) and fsGroup handling
- Files:
  - `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/harbor/helmrelease.yaml` (lines 44-48, 62-65)
  - Comment at line 110-112 indicates this was a known problem
- Trigger: When Longhorn PVCs don't properly handle fsGroup ownership changes on mount
- Workaround: Current security context with `fsGroup: 10000` and `fsGroupChangePolicy: OnRootMismatch` attempts to mitigate; may need explicit pod security policy or manual PVC permission corrections

**Trivy Database Mirror Fallback Incomplete:**
- Symptoms: Trivy vulnerability scanning may fail if mirror repositories are unavailable
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/harbor/helmrelease.yaml` (lines 175-180)
- Trigger: When `mirror.gcr.io` is unreachable and primary fallback fails
- Workaround: Uses fallback repositories but no retry logic specified; consider adding circuit breaker or alternative mirrors

## Security Considerations

**Privileged Container Mode in Dependabot Runner:**
- Risk: DinD (Docker-in-Docker) container runs with `privileged: true` security context
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/actions-runner-controller/dependabot-runner-scale-set-helmrelease.yaml` (line 142)
- Current mitigation: Runs in isolated namespace `arc-runners` with RBAC; only accessible to authorized CI/CD workflows
- Recommendations:
  - Document privileged mode requirement for CI/CD workflows
  - Consider using rootless Docker or gVisor sandboxing for improved isolation
  - Implement pod security policies to restrict privileged containers to specific namespaces
  - Audit container image sources regularly since it can execute arbitrary code

**OpenTelemetry Collection with auth_enabled: false:**
- Risk: Loki configured with `auth_enabled: false` allows unauthenticated log writes
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/loki/helmrelease.yaml` (line 27)
- Current mitigation: Loki only exposed internally within cluster; no external ingress
- Recommendations:
  - Enable authentication and implement proper token-based access
  - Consider network policies to restrict log ingestion to known collectors
  - Document that this configuration assumes network isolation

**Exposed MetalLB Annotations with Static IPs:**
- Risk: Keycloak ingress uses MetalLB annotation to reserve static IP `192.168.0.110`
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/keycloak/helmrelease.yaml` (line 91)
- Current mitigation: This is internal network configuration; assumes secure network environment
- Recommendations:
  - Document IP reservation strategy and allocation pools
  - Implement network policies to restrict access to cluster services
  - Consider DNS-based access instead of hardcoded IPs for flexibility

**Missing TLS Certificate Validation:**
- Risk: Multiple deployments reference TLS secrets but cert rotation/validation not automated
- Files: All ingress configurations referencing `secretName: xxx-tls` across multiple deployments
- Current mitigation: Manual certificate management documented; assumes manual renewal process
- Recommendations:
  - Implement cert-manager for automated certificate provisioning and renewal
  - Add cert-manager hooks to monitor certificate expiration
  - Document certificate storage location and backup procedures

## Performance Bottlenecks

**Loki Single Binary Deployment:**
- Problem: Loki deployed in SingleBinary mode with `replicas: 1` is a single point of failure for log aggregation
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/loki/helmrelease.yaml` (lines 24, 46)
- Cause: Simplified architecture; distributed mode requires more complex setup with separate read/write/backend components
- Improvement path:
  - Migrate to distributed mode with separate read/write/backend components when log volume exceeds current capacity
  - Implement persistence with redundancy (currently has single 200Gi PVC)
  - Add HA configuration with 3+ replicas once complexity is acceptable

**Redis Single Replica for Harbor:**
- Problem: Harbor's Redis cache has only 1 replica; any failure causes cache loss and performance degradation
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/harbor/redis.yaml` (line 20)
- Cause: Design simplification for ARM64 resource constraints
- Improvement path:
  - Add Redis Sentinel or cluster mode when cluster resources allow
  - Implement persistent AOF logging for data durability
  - Consider external managed Redis service for high availability

**Harbor Registry Storage Optimization:**
- Problem: Harbor registry uses single `ReadWriteOnce` 200Gi PVC; no sharding or distribution across nodes
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/harbor/helmrelease.yaml` (lines 106-109)
- Cause: Longhorn storage limitation; RWO access mode doesn't support true multi-node distribution
- Improvement path:
  - Monitor actual storage utilization; may need to increase size before hitting limits
  - Consider tiering to object storage (MinIO, S3) for registry images if growth exceeds Longhorn capacity
  - Implement registry replication across multiple nodes if high availability becomes critical

**Prometheus Retention at 450GB Soft Limit:**
- Problem: Prometheus configured with 10-day retention and 450GB soft limit; near-full metrics data age rapidly
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/kube-prometheus-stack/helmrelease.yaml` (lines 37-38)
- Cause: 500Gi PVC allocated for monitoring stack; storage constrained on ARM64 cluster
- Improvement path:
  - Profile actual ingestion rate; if exceeding 45GB/day, extend retention requires more storage
  - Implement metrics downsampling or aggregation rules for historical data
  - Consider external time-series database (Cortex, Thanos) for longer retention

## Fragile Areas

**Multiple Helm Chart Version Dependencies:**
- Files: All HelmRelease specs across `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/`
- Why fragile: Each application pinned to specific Helm chart version (Harbor 1.18.1, Loki 6.52.0, etc.); chart updates may include breaking changes
- Safe modification:
  - Review Helm chart release notes before updating version
  - Test upgrades in non-production first
  - Use Flux automated image updates (imageUpdateAutomation) with caution on values that interact with other components
- Test coverage: Gaps - no integration tests validate cross-component compatibility after chart updates

**Keycloak as Authentication Dependency:**
- Files:
  - `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/forgejo/helmrelease.yaml` (lines 72-76)
  - `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/kube-prometheus-stack/helmrelease.yaml` (lines 73-89)
- Why fragile: Forgejo and Grafana authentication depend on Keycloak OIDC; any Keycloak outage disables authentication for both
- Safe modification:
  - Implement fallback authentication mechanisms (local accounts as backup)
  - Monitor Keycloak availability; setup alerts for auth failures
  - Test Keycloak failover scenarios regularly
- Test coverage: No documented test scenarios for Keycloak unavailability

**Actions Runner Controller with Multiple Scale Sets:**
- Files: Multiple scale set configurations across `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/actions-runner-controller/`
  - `claude-scale-set-helmrelease.yaml` (claude runner)
  - `dependabot-runner-scale-set-helmrelease.yaml` (dependabot, uses dind)
  - `code-quality-runner-helmrelease.yaml` (code quality)
  - `runner-scale-set-helmrelease.yaml` (generic)
  - Plus manual RunnerSet files (modbus, opcua)
- Why fragile: Different image versions (`v0.1.5`, `v0.2.1`, `v0.3.6`, `latest`), different configurations, mixed DinD vs non-DinD
- Safe modification:
  - Standardize runner images to common base version or implement image update strategy
  - Test each scale set independently before cluster-wide changes
  - Document why each scale set needs different configuration
- Test coverage: No documented CI tests for runner scaling behavior or workload capacity

**Longhorn Storage as Single Point of Failure:**
- Files: All deployments reference `storageClassName: longhorn` for persistence
- Why fragile: Longhorn manages all cluster storage; any Longhorn controller failure affects all PVCs
- Safe modification:
  - Maintain regular Longhorn backups to external storage
  - Test Longhorn recovery procedures monthly
  - Monitor Longhorn replica status; alerts for degraded volumes
- Test coverage: No backup/restore testing documented

## Scaling Limits

**Cluster-Wide Storage Capacity:**
- Current capacity: Various PVCs totaling approximately 1.3TB+ (500Gi Prometheus + 200Gi Harbor registry + 200Gi Loki + 300Gi MinIO + others)
- Limit: Single k3s cluster on ARM64 likely has < 2TB available storage; no distributed storage tier
- Scaling path:
  - Monitor actual disk utilization monthly
  - Implement tiered storage with hot/cold data policies
  - Consider adding secondary storage nodes with distributed Longhorn replica placement
  - Plan for external object storage migration if image/log volume exceeds capacity

**Prometheus Metrics Ingestion Rate:**
- Current capacity: 500Gi at 10-day retention suggests ~50Gi/day ingestion at steady state
- Limit: As monitoring scope expands (more targets, higher cardinality metrics), will quickly exceed 10-day retention
- Scaling path:
  - Profile cardinality with `topk(100, count(ALERTS))` queries
  - Implement metric relabeling to drop high-cardinality labels
  - Migrate to Thanos or Cortex for long-term storage at higher scale
  - Plan for 100+ node clusters with separate monitoring infrastructure

**Container Image Registry Capacity:**
- Current capacity: Harbor registry 200Gi PVC; serves container images for all cluster workloads + external pull-throughs
- Limit: 200Gi fills quickly with base OS images, language runtimes, application images if CI/CD pushes frequently
- Scaling path:
  - Implement image garbage collection policies (remove untagged images)
  - Consider tiering to S3/MinIO backend when approaching 150Gi utilization
  - Monitor pull-through proxy cache hit rates to optimize external registry caching

**Runner Pod Scaling:**
- Current capacity: Claude runner max 10 pods × 4Gi memory = 40Gi, Dependabot max 10 pods × 4Gi = 40Gi, plus others
- Limit: Total runner capacity constrained by cluster memory/CPU; ephemeral storage requests add Longhorn pressure
- Scaling path:
  - Monitor runner queue time; if high, increase maxRunners or add secondary runner cluster
  - Implement runner job timeout to prevent stuck runners consuming resources
  - Consider dedicated runner node pool with larger storage

## Dependencies at Risk

**Longhorn Storage Driver:**
- Risk: ARM64 platform support historically lagged in Longhorn; open-iscsi/nfs-common prerequisites required on all nodes
- Impact: Storage initialization failure blocks entire cluster; no storage = no persistent data
- Migration plan:
  - Document exact Longhorn version requirements for ARM64
  - Test storage migration to alternative drivers (RancherLocalPath for local storage, NFS for network storage) if issues emerge
  - Keep filesystem backups separate from Longhorn

**Helm Chart Repository Availability:**
- Risk: Multiple external Helm repos referenced (Bitnami, Prometheus Community, Codecentric, Grafana, Harbor, MinIO); if repos become unavailable, cannot deploy updates
- Impact: Stuck on current chart versions; cannot apply security patches or bug fixes without manual workarounds
- Migration plan:
  - Document all Helm repository URLs for recovery
  - Consider mirroring critical charts to private registry or using Flux with local chart sources
  - Monitor repo availability; alert on chart fetch failures

**GHCR (GitHub Container Registry) Dependency:**
- Risk: Multiple GHCR image pulls in Harbor, Trivy, and other components; GitHub service availability affects container pulls
- Impact: Pod creation failures if GHCR is down or rate-limited
- Migration plan:
  - Implement local image caching in Harbor
  - Consider mirror.gcr.io or other public mirrors as fallbacks
  - Monitor GHCR rate limiting; implement pull-through caching

**External Database Dependencies:**
- Risk: Forgejo uses external PostgreSQL (not HA), Keycloak uses external PostgreSQL, Harbor has internal DB
- Impact: Database loss affects application data; no documented backup strategy
- Migration plan:
  - Document database backup procedures and retention policy
  - Implement automated backups to external storage
  - Consider managed database services (AWS RDS, Cloud SQL) for critical data
  - Test recovery procedures monthly

## Missing Critical Features

**High Availability (HA) Deployments:**
- Problem: Most applications running with single replicas (Loki, Redis, Harbor internal DB, Keycloak would benefit from HA)
- Blocks: Cannot tolerate any node maintenance without service interruption; no rolling updates possible
- Implementation approach:
  - Add replica counts (minimum 2-3) to stateless components
  - Implement distributed database modes for stateful components
  - Setup pod anti-affinity to spread replicas across nodes

**Backup and Disaster Recovery:**
- Problem: No automated backup system for databases, configuration, or persistent data
- Blocks: Data loss recovery impossible; configuration drift undetectable
- Implementation approach:
  - Deploy backup operator (Velero) for cluster-wide backup/restore
  - Implement separate backup storage (S3, external NFS)
  - Document and test monthly RTO/RPO targets

**Network Policies:**
- Problem: No network policies documented; all pods can communicate with all other pods
- Blocks: Cannot comply with security standards requiring network segmentation; lateral movement possible after pod compromise
- Implementation approach:
  - Implement network policies to restrict ingress/egress by namespace and service
  - Document service dependencies and create corresponding allow rules
  - Test network policies don't break inter-service communication

**Automated Certificate Rotation:**
- Problem: TLS certificates referenced in ingress resources but rotation mechanism not documented
- Blocks: Certificate expiration will silently cause service outages unless manually renewed
- Implementation approach:
  - Deploy cert-manager with Let's Encrypt or private CA
  - Implement automated renewal with monitoring/alerts for failed renewals
  - Document current certificate locations for manual backup

**Resource Requests/Limits Audit:**
- Problem: Some components have conservative resource requests that may be insufficient; others lack limits
- Blocks: Cannot predict cluster utilization or prevent resource exhaustion attacks
- Implementation approach:
  - Profile each application to determine actual resource usage
  - Set realistic requests based on profiling data
  - Set appropriate limits to prevent runaway processes

## Test Coverage Gaps

**Harbor Upgrade Path:**
- What's not tested: Harbor minor/major version upgrades; persistence through database schema migrations
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/harbor/helmrelease.yaml`
- Risk: Upgrade failures leave Harbor inaccessible; data corruption possible with incompatible schema
- Priority: High - Harbor is critical infrastructure

**Keycloak OIDC Integration Failure Mode:**
- What's not tested: Keycloak unavailability; OIDC auth token refresh failures; realm configuration changes
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/keycloak/helmrelease.yaml`
- Risk: Silent authentication failures; users locked out without visibility into root cause
- Priority: High - affects Forgejo and Grafana access

**Actions Runner Scale Set Behavior:**
- What's not tested: Scaling up/down under load; job queue handling; image pull failures
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/actions-runner-controller/*-helmrelease.yaml`
- Risk: Runners fail to scale when needed; CI/CD pipeline stalls unnoticed
- Priority: High - blocks development workflow

**Longhorn Storage Failure Recovery:**
- What's not tested: Node failure with Longhorn volumes; replica rebuild times; backup/restore
- Files: All deployments using `storageClassName: longhorn`
- Risk: Unplanned downtime; data loss if replicas don't rebuild; recovery procedures unclear
- Priority: Critical - affects all stateful services

**OpenTelemetry Collection Path:**
- What's not tested: Log collection under high volume; parser correctness for different container runtimes; Loki retention enforcement
- Files: `/Users/ravichillerega/sources/core/infra/clusters/k3s-cluster/apps/opentelemetry-collector/helmrelease.yaml`
- Risk: Silent log loss; parsing failures leave raw logs unindexed; retention policy not enforced silently
- Priority: Medium - affects observability but doesn't block workloads

---

*Concerns audit: 2026-02-28*
