# Harbor Cosign Setup Guide

## Overview

Harbor 2.13.0 supports Cosign for container image signing and verification, providing enhanced security for your container registry. Cosign allows you to sign container images and verify their integrity and authenticity.

## Prerequisites

- Harbor 2.13.0 or later (✅ Currently deployed)
- Cosign CLI installed on your local machine
- Access to Harbor web interface with project admin privileges

## Installation

### Install Cosign CLI

```bash
# Download and install Cosign
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-arm64"
sudo mv cosign-linux-arm64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Verify installation
cosign version
```

## Configuration

### 1. Enable Cosign in Harbor Project

1. **Access Harbor Web Interface**
   - Navigate to `https://harbor.theedgeworks.ai`
   - Log in with your credentials

2. **Configure Project**
   - Go to your project (or create a new one)
   - Navigate to **Configuration** tab
   - Under **Deployment Security**, enable **Cosign**
   - Save the configuration

### 2. Generate Cosign Key Pair

```bash
# Generate a new key pair
cosign generate-key-pair

# This creates:
# - cosign.key (private key - keep secure)
# - cosign.pub (public key - can be shared)
```

### 3. Store Keys Securely

```bash
# Store private key securely (example with Kubernetes secret)
kubectl create secret generic cosign-private-key \
  --from-file=cosign.key=./cosign.key \
  --namespace=harbor

# Store public key (can be shared)
kubectl create secret generic cosign-public-key \
  --from-file=cosign.pub=./cosign.pub \
  --namespace=harbor
```

## Usage

### Signing Images

```bash
# Login to Harbor
docker login harbor.theedgeworks.ai

# Build and push your image
docker build -t harbor.theedgeworks.ai/your-project/your-image:latest .
docker push harbor.theedgeworks.ai/your-project/your-image:latest

# Sign the image
cosign sign --key cosign.key harbor.theedgeworks.ai/your-project/your-image:latest
```

### Verifying Images

```bash
# Verify image signature
cosign verify --key cosign.pub harbor.theedgeworks.ai/your-project/your-image:latest
```

### Advanced Usage

```bash
# Sign with specific annotations
cosign sign --key cosign.key \
  --annotation "build-time=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --annotation "build-commit=$(git rev-parse HEAD)" \
  harbor.theedgeworks.ai/your-project/your-image:latest

# Verify with specific annotations
cosign verify --key cosign.pub \
  --annotation "build-time" \
  harbor.theedgeworks.ai/your-project/your-image:latest
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Build and Sign
on:
  push:
    branches: [main]

jobs:
  build-and-sign:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Harbor
      uses: docker/login-action@v2
      with:
        registry: harbor.theedgeworks.ai
        username: ${{ secrets.HARBOR_USERNAME }}
        password: ${{ secrets.HARBOR_PASSWORD }}
    
    - name: Build and push
      uses: docker/build-push-action@v3
      with:
        context: .
        push: true
        tags: harbor.theedgeworks.ai/your-project/your-image:${{ github.sha }}
    
    - name: Install Cosign
      uses: sigstore/cosign-installer@v2
    
    - name: Sign image
      run: |
        cosign sign --key ${{ secrets.COSIGN_PRIVATE_KEY }} \
          harbor.theedgeworks.ai/your-project/your-image:${{ github.sha }}
```

## Security Best Practices

1. **Key Management**
   - Store private keys securely (use Kubernetes secrets, HashiCorp Vault, etc.)
   - Rotate keys regularly
   - Use different keys for different environments

2. **Verification**
   - Always verify signatures before deploying images
   - Implement policy enforcement (e.g., with Kyverno)
   - Monitor for unsigned images

3. **Access Control**
   - Limit who can sign images
   - Use RBAC to control Cosign access
   - Audit signing activities

## Troubleshooting

### Common Issues

1. **Signature Not Found**
   ```bash
   # Check if image exists and is signed
   cosign verify --key cosign.pub harbor.theedgeworks.ai/project/image:tag
   ```

2. **Key Mismatch**
   ```bash
   # Ensure you're using the correct public key
   cosign verify --key cosign.pub harbor.theedgeworks.ai/project/image:tag
   ```

3. **Harbor Project Not Configured**
   - Verify Cosign is enabled in project settings
   - Check project permissions

### Useful Commands

```bash
# List signatures for an image
cosign tree harbor.theedgeworks.ai/project/image:tag

# Verify all signatures
cosign verify --key cosign.pub --all harbor.theedgeworks.ai/project/image:tag

# Check Cosign version
cosign version
```

## Integration with Policy Enforcement

### Kyverno Policy Example

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: check-image-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "All images must be signed with Cosign"
      pattern:
        spec:
          containers:
          - name: "*"
            image: "harbor.theedgeworks.ai/*"
      verifyImages:
      - imageReferences:
        - "harbor.theedgeworks.ai/*"
        attestors:
        - count: 1
          entries:
          - keys:
              publicKeys: |-
                -----BEGIN PUBLIC KEY-----
                # Your public key here
                -----END PUBLIC KEY-----
```

## Resources

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview)
- [Harbor Cosign Integration](https://goharbor.io/docs/latest/working-with-projects/working-with-images/signing-images-with-cosign/)
- [Sigstore Project](https://sigstore.dev/)
