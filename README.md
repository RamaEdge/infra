# Infrastructure GitOps Repository

This repository contains the GitOps configuration for deploying Harbor, MinIO, and related services on a k3s cluster using Flux.

## Prerequisites

- A running k3s cluster.
- Flux installed and configured.
- TLS certificates and keys for ingress (stored as Kubernetes secrets).
- Required credentials (stored as Kubernetes secrets).

## Secret Management

The following secrets are required and must be created locally (not managed by Flux):

- **TLS Secret:** `ramaedge-tls-secret` (for ingress TLS)
- **MinIO Credentials:** `minio-credentials` (username: admin, password: RamaedgeMinio692#)
- **Harbor DB Credentials:** `harbor-db-credentials` (username: harbor, password: RamaedgeHarbor692#)

To create these secrets, run:

```bash
kubectl create secret tls ramaedge-tls-secret --cert=/path/to/cert.crt --key=/path/to/key.key
kubectl create secret generic minio-credentials --from-literal=username=admin --from-literal=password=RamaedgeMinio692#
kubectl create secret generic harbor-db-credentials --from-literal=username=harbor --from-literal=password=RamaedgeHarbor692#
```

## Deployment

1. Ensure all required secrets are created.
2. Push changes to this repository.
3. Flux will automatically deploy the infrastructure.

## Components

- **Harbor:** Container registry with external PostgreSQL and Redis.
- **MinIO:** Object storage with 300Gi persistent storage.

## Troubleshooting

If you encounter issues, check the Flux logs and ensure all secrets are correctly configured. 