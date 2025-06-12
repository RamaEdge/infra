# RamaEdge Infrastructure

This repository contains the infrastructure-as-code definitions for the RamaEdge Kubernetes cluster.

## Structure

- `clusters/k3s-cluster/` - Cluster-specific configurations
  - `flux-system/` - Flux system configuration
  - `apps/` - Application deployments
- `base/` - Base configurations for reusable components

## Applications

### Harbor
Container registry for storing and managing container images.
- **Namespace**: `harbor`
- **Access**: https://harbor.ramaedge.local

### MinIO
S3-compatible object storage with 300GB capacity.
- **Namespace**: `minio-tenant`
- **Console**: https://console.ramaedge.local
- **API**: https://minio.ramaedge.local

### OpenTelemetry
Observability and telemetry collection.
- **Namespace**: `opentelemetry-system`

## Deployment

This repository is automatically deployed using Flux GitOps on the k3s cluster.

## Security

- Secrets are managed locally on the cluster
- TLS certificates are stored as Kubernetes secrets
- No sensitive data is committed to this repository 