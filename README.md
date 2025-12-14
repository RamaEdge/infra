# Infrastructure GitOps Repository

This repository contains the GitOps configuration for deploying Harbor, MinIO, and related services on a k3s cluster using Flux.

## Prerequisites

- A running k3s cluster.
- TLS certificates and keys for ingress (stored as Kubernetes secrets).
- Required credentials (stored as Kubernetes secrets).

## Installing Flux

### Step 1: Install Flux CLI

Install the Flux CLI on your local machine:

```bash
# Linux/ARM64 (Raspberry Pi)
curl -s https://fluxcd.io/install.sh | sudo bash

# Or download directly
wget https://github.com/fluxcd/flux2/releases/latest/download/flux_linux_arm64.tar.gz
tar -xzf flux_linux_arm64.tar.gz
sudo mv flux /usr/local/bin/
```

Verify installation:
```bash
flux version
```

### Step 2: Install Flux Components on Cluster

Install Flux components in your k3s cluster:

```bash
flux install --components-extra=image-reflector-controller,image-automation-controller
```

Wait for CRDs to be ready:
```bash
kubectl wait --for condition=established --timeout=60s crd/kustomizations.kustomize.toolkit.fluxcd.io
kubectl wait --for condition=established --timeout=60s crd/gitrepositories.source.toolkit.fluxcd.io
```

### Step 3: Bootstrap infra-core Repository (First)

Bootstrap Flux with the `infra-core` repository first (this deploys core infrastructure like MetalLB and Longhorn):

```bash
# For public repositories
flux bootstrap github \
  --owner=ramaedge \
  --repository=infra-core \
  --branch=main \
  --path=./clusters/k3s-cluster \
  --namespace=flux-system \
  --components-extra=image-reflector-controller,image-automation-controller

# For private repositories, add authentication
export GITHUB_TOKEN=<your-github-token>
flux bootstrap github \
  --owner=ramaedge \
  --repository=infra-core \
  --branch=main \
  --path=./clusters/k3s-cluster \
  --namespace=flux-system \
  --components-extra=image-reflector-controller,image-automation-controller \
  --token-auth
```

### Step 4: Add infra Repository (Second)

After `infra-core` is syncing, add this repository as a second source. Create the GitRepository and Kustomization:

```bash
# Create GitRepository for infra
flux create source git infra \
  --url=https://github.com/ramaedge/infra.git \
  --branch=main \
  --namespace=flux-system \
  --secret-ref=infra \
  --export > clusters/k3s-cluster/flux-system/infra-gitrepository.yaml

# Create Kustomization for infra (depends on infra-core)
flux create kustomization infra \
  --source=infra \
  --path=./clusters/k3s-cluster \
  --prune=true \
  --namespace=flux-system \
  --depends-on=infra-core \
  --export > clusters/k3s-cluster/flux-system/infra-kustomization.yaml
```

If the repository is private, create the authentication secret:

```bash
flux create secret git infra \
  --namespace=flux-system \
  --url=https://github.com/ramaedge/infra.git \
  --username=<github-username> \
  --password=<github-token>
```

## Longhorn Prerequisites

Longhorn requires specific OS packages to be installed on **all nodes** in your cluster:

### Required Packages

Install on all nodes (Raspberry Pi OS / Debian-based):

```bash
# Update package list
sudo apt-get update

# Install open-iscsi (required for Longhorn persistent volumes)
sudo apt-get install -y open-iscsi

# Install NFS client (required for RWX volumes and backups)
sudo apt-get install -y nfs-common

# Enable and start iscsid service
sudo systemctl enable iscsid
sudo systemctl start iscsid

# Verify installation
iscsiadm --version
dpkg -l | grep -E "open-iscsi|nfs-common"
```

### Verification

Verify all prerequisites are met:

```bash
# Check iscsid is running
sudo systemctl status iscsid

# Check iSCSI tools are available
which iscsiadm
iscsiadm --version

# Check NFS client is installed
dpkg -l | grep nfs-common

# Check kernel modules
lsmod | grep iscsi
```

### Additional Requirements

- **Kernel**: Minimum 5.19+ (your kernel 6.12.47 meets this requirement)
- **Filesystem**: ext4 or XFS (supports file extents)
- **Storage**: Dedicated disk recommended (not root disk)
- **Architecture**: ARM64 supported (Raspberry Pi compatible)

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

1. **Install Flux** (see above)
2. **Bootstrap infra-core** repository first
3. **Add infra repository** as second source
4. **Install Longhorn prerequisites** on all nodes
5. **Create required secrets** (see Secret Management below)
6. Push changes to this repository
7. Flux will automatically deploy the infrastructure

### Verify Deployment

```bash
# Check Flux status
kubectl get pods -n flux-system
flux get kustomizations -n flux-system
flux get sources git -n flux-system

# Check Longhorn deployment
kubectl get pods -n longhorn-system

# Check application deployments
kubectl get pods -n harbor
kubectl get pods -n minio-tenant
```

## Components

- **MetalLB:** Load balancer for bare-metal Kubernetes (deployed from infra-core)
- **Longhorn:** Distributed block storage for Kubernetes (deployed from infra-core)
- **Harbor:** Container registry with external PostgreSQL and Redis
- **MinIO:** Object storage with 300Gi persistent storage

## Troubleshooting

### Flux Issues

If you encounter Flux-related errors:

```bash
# Check Flux components
kubectl get pods -n flux-system

# Check GitRepository status
kubectl describe gitrepository -n flux-system

# Check Kustomization status
kubectl describe kustomization -n flux-system

# View Flux logs
kubectl logs -n flux-system -l app=helm-controller
kubectl logs -n flux-system -l app=kustomize-controller
```

### Longhorn Issues

If Longhorn fails to deploy:

```bash
# Check Longhorn pods
kubectl get pods -n longhorn-system

# Check Longhorn manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager

# Verify prerequisites are installed
kubectl get nodes -o wide
# Then SSH to each node and verify:
# - iscsid service is running
# - open-iscsi and nfs-common packages are installed
```

### Common Issues

1. **"no matches for kind Kustomization"**: Flux CRDs not installed. Run `flux install` first.
2. **Longhorn pods in CrashLoopBackOff**: Check if `open-iscsi` and `nfs-common` are installed on all nodes.
3. **GitRepository authentication errors**: Ensure secrets are created for private repositories.
4. **Kustomization sync failures**: Check path in Kustomization matches repository structure.

If you encounter issues, check the Flux logs and ensure all secrets are correctly configured. 