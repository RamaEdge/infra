# Deployment Guide

## Prerequisites

1. **GitHub Repository**: Create `ramaedge/infra` repository on GitHub
2. **Flux CLI**: Install Flux CLI on your local machine
3. **Kubernetes Cluster**: k3s cluster with Flux already installed

## Step 1: Create GitHub Repository

1. Go to GitHub and create a new repository: `ramaedge/infra`
2. Make it public (or configure SSH/PAT for private access)
3. Clone this repository structure to the new repo

## Step 2: Update Flux Configuration

Replace the current Flux GitRepository to point to the new infra repository:

```bash
# Update the existing GitRepository
kubectl patch gitrepository flux-system -n flux-system --type='json' -p='[
  {"op": "replace", "path": "/spec/url", "value": "https://github.com/ramaedge/infra.git"},
  {"op": "replace", "path": "/spec/ref/branch", "value": "main"}
]'

# Update the Kustomization path
kubectl patch kustomization flux-system -n flux-system --type='json' -p='[
  {"op": "replace", "path": "/spec/path", "value": "./clusters/k3s-cluster"}
]'
```

## Step 3: Configure OpenTelemetry

Update the OpenTelemetry configuration:

1. Edit `clusters/k3s-cluster/apps/opentelemetry/source.yaml`
2. Replace the URL with your actual OpenTelemetry repository
3. Adjust the path in `kustomization.yaml` if needed

## Step 4: Verify Deployment

```bash
# Check Flux status
kubectl get gitrepositories,kustomizations -A

# Check application deployments
kubectl get pods -n harbor
kubectl get pods -n minio-tenant
kubectl get pods -n opentelemetry-system
```

## Security Notes

- **Secrets**: All secrets (TLS certificates, credentials) remain on the cluster
- **No sensitive data**: This repository contains no passwords or certificates
- **Secret references**: Manifests reference existing secrets by name

## Troubleshooting

- **Authentication errors**: Ensure the repository is public or configure proper authentication
- **Path errors**: Verify the directory structure matches the Kustomization paths
- **Secret references**: Ensure all referenced secrets exist on the cluster 