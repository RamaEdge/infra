# MinIO SSO Configuration

This guide covers configuring MinIO to authenticate via Keycloak OIDC.

## Prerequisites

- Keycloak realm and client configured (see [keycloak-setup.md](keycloak-setup.md))
- Client secret from Keycloak
- MinIO Operator deployed

## Step 1: Create Kubernetes Secret

Create the secret in the `minio-tenant` namespace:

```bash
kubectl create secret generic keycloak-oidc \
  -n minio-tenant \
  --from-literal=client-id='theedgeworks' \
  --from-literal=client-secret='YOUR_CLIENT_SECRET'
```

Replace `YOUR_CLIENT_SECRET` with the client secret from Keycloak.

### Verify Secret
```bash
kubectl get secret keycloak-oidc -n minio-tenant
```

## Step 2: Update MinIO Tenant Configuration

The MinIO tenant is configured in `clusters/k3s-cluster/apps/minio/tenant.yaml`.

### Add OIDC Environment Variables

```yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
spec:
  # ... existing config ...
  
  env:
    - name: MINIO_SERVER_URL
      value: "https://storage.theedgeworks.ai"
    - name: MINIO_BROWSER_REDIRECT_URL
      value: "https://storage-console.theedgeworks.ai"
    
    # OIDC Configuration
    - name: MINIO_IDENTITY_OPENID_CONFIG_URL
      value: "https://auth.theedgeworks.ai/realms/theedgeworks/.well-known/openid-configuration"
    - name: MINIO_IDENTITY_OPENID_CLIENT_ID
      valueFrom:
        secretKeyRef:
          name: keycloak-oidc
          key: client-id
    - name: MINIO_IDENTITY_OPENID_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: keycloak-oidc
          key: client-secret
    - name: MINIO_IDENTITY_OPENID_CLAIM_NAME
      value: "policy"  # Claim containing the MinIO policy name
    - name: MINIO_IDENTITY_OPENID_CLAIM_PREFIX
      value: ""
    - name: MINIO_IDENTITY_OPENID_SCOPES
      value: "openid,profile,email"
    - name: MINIO_IDENTITY_OPENID_REDIRECT_URI
      value: "https://storage-console.theedgeworks.ai/oauth_callback"
    - name: MINIO_IDENTITY_OPENID_CLAIM_USERINFO
      value: "on"
    - name: MINIO_IDENTITY_OPENID_DISPLAY_NAME
      value: "Keycloak"
```

## Step 3: Configure Keycloak Policy Mapper

MinIO uses a `policy` claim to determine user permissions. Create a mapper in Keycloak:

1. Go to **Clients** → `theedgeworks` → **Client scopes**
2. Click on `theedgeworks-dedicated`
3. Go to **Mappers** → **Add mapper** → **By configuration**
4. Select **User Attribute** or **Hardcoded claim**

### Option A: Hardcoded Policy (All users get same policy)

| Field | Value |
|-------|-------|
| Name | `minio-policy` |
| Token Claim Name | `policy` |
| Claim value | `readwrite` |
| Add to ID token | ON |
| Add to access token | ON |
| Add to userinfo | ON |

### Option B: Group-Based Policy

For group-based policy mapping, change the claim name to `groups`:

1. Update `MINIO_IDENTITY_OPENID_CLAIM_NAME` in tenant.yaml:
   ```yaml
   - name: MINIO_IDENTITY_OPENID_CLAIM_NAME
     value: "groups"
   ```

2. Create a **Group Membership** mapper in Keycloak:
   | Field | Value |
   |-------|-------|
   | Name | `groups` |
   | Token Claim Name | `groups` |
   | Full group path | OFF |
   | Add to ID token | ON |
   | Add to access token | ON |
   | Add to userinfo | ON |

3. Create Keycloak groups that **exactly match** MinIO policy names:
   - `readonly` → MinIO `readonly` policy
   - `readwrite` → MinIO `readwrite` policy
   - `consoleAdmin` → MinIO `consoleAdmin` policy

4. Assign users to appropriate groups in Keycloak

**Note**: With this approach, the Keycloak group name must exactly match a MinIO policy name.

## MinIO Policies

Built-in policies:
| Policy | Description |
|--------|-------------|
| `readonly` | Read-only access to all buckets |
| `readwrite` | Read/write access to all buckets |
| `writeonly` | Write-only access |
| `diagnostics` | Diagnostic endpoints access |
| `consoleAdmin` | Full console admin access |

### Create Custom Policy
```bash
# Using mc (MinIO Client)
mc admin policy create myminio my-policy policy.json
```

Example `policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": ["arn:aws:s3:::my-bucket/*"]
    }
  ]
}
```

## Step 4: Apply Configuration

```bash
# Commit and push
git add -A && git commit -m "Configure MinIO OIDC" && git push

# Reconcile Flux
flux reconcile source git infra
flux reconcile kustomization infra -n flux-system
```

## Keycloak Redirect URI

Ensure this redirect URI is configured in Keycloak:
```
https://storage-console.theedgeworks.ai/oauth_callback
```

## Troubleshooting

### OIDC Login Button Not Appearing
- Verify all OIDC environment variables are set
- Check MinIO pods restarted after config change
- Verify secret exists in correct namespace

### Policy Not Applied
- Check the policy claim is being sent in the token
- Verify claim name matches `MINIO_IDENTITY_OPENID_CLAIM_NAME`
- Test token contents at jwt.io

### Check MinIO Logs
```bash
kubectl logs -n minio-tenant -l v1.min.io/tenant=minio-tenant | grep -i oidc
```

### Verify OIDC Configuration
```bash
# Check environment variables in pod
kubectl exec -n minio-tenant <minio-pod> -- env | grep MINIO_IDENTITY
```

## Fallback Authentication

MinIO root credentials remain available as fallback:
- Username: from `minio-credentials` secret
- Password: from `minio-credentials` secret

Access via:
```bash
mc alias set myminio https://storage.theedgeworks.ai ACCESS_KEY SECRET_KEY
```

## Access

- **Console URL**: `https://storage-console.theedgeworks.ai`
- **API URL**: `https://storage.theedgeworks.ai`
- **SSO Login**: Click "Login with SSO" or "Keycloak"

