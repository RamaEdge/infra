# Grafana Keycloak SSO Setup Guide

This guide explains how to configure Keycloak OIDC authentication for Grafana.

## Prerequisites

- Keycloak server running at `https://auth.theedgeworks.ai`
- A realm created (e.g., `theedgeworks`)
- Google Identity Provider configured in the realm (optional, for Google SSO)

## Step 1: Create OIDC Client in Keycloak

1. Login to Keycloak Admin Console: `https://auth.theedgeworks.ai/admin/`
2. Select your realm (e.g., `theedgeworks`)
3. Navigate to **Clients** → **Create client**

### General Settings
| Field | Value |
|-------|-------|
| Client type | OpenID Connect |
| Client ID | `theedgeworks` (or your preferred name) |

Click **Next**

### Capability Config
| Setting | Value |
|---------|-------|
| Client authentication | ON |
| Authorization | OFF |
| Standard flow | ON |
| Direct access grants | OFF |
| Implicit flow | OFF |
| Service accounts roles | OFF |

Click **Next**

### Login Settings
| Field | Value |
|-------|-------|
| Root URL | `https://monitor.theedgeworks.ai` |
| Home URL | `https://monitor.theedgeworks.ai` |
| Valid redirect URIs | See table below |
| Valid post logout redirect URIs | See table below |
| Web origins | `https://*.theedgeworks.ai` |

#### Redirect URIs (for shared client supporting multiple services)

**Valid redirect URIs:**
| Service | Redirect URI |
|---------|-------------|
| Grafana | `https://monitor.theedgeworks.ai/login/generic_oauth` |
| MinIO | `https://storage-console.theedgeworks.ai/oauth_callback` |
| Harbor | `https://harbor.theedgeworks.ai/c/oidc/callback` |
| Longhorn | `https://longhorn.theedgeworks.ai/oauth2/callback` |

**Valid post logout redirect URIs:**
| Service | Post Logout Redirect URI |
|---------|-------------------------|
| Grafana | `https://monitor.theedgeworks.ai/login` |
| MinIO | `https://storage-console.theedgeworks.ai` |
| Harbor | `https://harbor.theedgeworks.ai` |
| Longhorn | `https://longhorn.theedgeworks.ai` |

> **Note:** Post logout redirect URIs tell Keycloak where to redirect users after they log out. These must be whitelisted in Keycloak for the logout flow to work properly.

Click **Save**

## Step 2: Get Client Secret

1. Go to **Clients** → `theedgeworks` → **Credentials** tab
2. Copy the **Client secret** value
3. Save it securely - you'll need it for the Kubernetes secret

## Step 3: Configure Client Scopes

Ensure the client has the required scopes assigned:

1. Go to **Clients** → `theedgeworks` → **Client scopes** tab
2. Verify these are in **Assigned default client scopes**:
   - `openid` (required for OIDC)
   - `email` (required for user email)
   - `profile` (required for user name)

If any are missing:
1. Click **Add client scope**
2. Select the missing scope
3. Click **Add** → **Default**

## Step 4: Create Groups Mapper (for Role-Based Access)

To enable Grafana Admin/Viewer role mapping based on Keycloak groups:

1. Go to **Clients** → `theedgeworks` → **Client scopes** tab
2. Click on `theedgeworks-dedicated` (the dedicated scope for your client)
3. Go to **Mappers** tab → **Add mapper** → **By configuration**
4. Select **Group Membership**
5. Configure:

| Field | Value |
|-------|-------|
| Name | `groups` |
| Token Claim Name | `groups` |
| Full group path | OFF |
| Add to ID token | ON |
| Add to access token | ON |
| Add to userinfo | ON |

6. Click **Save**

## Step 5: Create Groups for Role Mapping

### Create Admin Group
1. Go to **Groups** (in left menu)
2. Click **Create group**
3. Name: `grafana-admin`
4. Click **Create**

### Assign Users to Groups
1. Go to **Users** → Select a user
2. Go to **Groups** tab
3. Click **Join Group**
4. Select `grafana-admin`
5. Click **Join**

## Step 6: Create Kubernetes Secret

Create the secret in the `monitoring` namespace with the client credentials:

```bash
kubectl create secret generic keycloak-oidc \
  -n monitoring \
  --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET='YOUR_CLIENT_SECRET_HERE'
```

Replace `YOUR_CLIENT_SECRET_HERE` with the client secret from Step 2.

### Verify Secret
```bash
kubectl get secret keycloak-oidc -n monitoring
```

## Step 7: Grafana Configuration

The Grafana HelmRelease is pre-configured with Keycloak OIDC settings in `helmrelease.yaml`.

Key configuration values:
```yaml
auth.generic_oauth:
  enabled: true
  name: Keycloak
  allow_sign_up: true
  client_id: theedgeworks
  scopes: openid profile email
  use_pkce: true
  auth_url: https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/auth
  token_url: https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/token
  api_url: https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/userinfo
  email_attribute_path: email
  login_attribute_path: email
  name_attribute_path: name
  groups_attribute_path: groups
  role_attribute_path: contains(groups[*], 'grafana-admin') && 'Admin' || 'Viewer'
```

## Role Mapping

| Keycloak Group | Grafana Role | Permissions |
|----------------|--------------|-------------|
| `grafana-admin` | Admin | Full organization admin access |
| (no group) | Viewer | Read-only access |

To add more roles (e.g., Editor):
```yaml
role_attribute_path: contains(groups[*], 'grafana-admin') && 'Admin' || contains(groups[*], 'grafana-editor') && 'Editor' || 'Viewer'
```

## Troubleshooting

### User sync failed
- Ensure `email`, `profile`, and `openid` scopes are assigned to the client
- Verify `oauth_allow_insecure_email_lookup: true` is set in Grafana config

### Groups not working
- Verify the groups mapper is configured correctly
- Check that "Add to userinfo" is enabled in the mapper
- Ensure users are actually assigned to the groups

### Check Grafana logs
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana | grep -i oauth
```

### Test Keycloak userinfo endpoint
```bash
# Get a token first, then:
curl -H "Authorization: Bearer TOKEN" \
  https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/userinfo
```

## Adding More Services

To add OIDC for other services (MinIO, Harbor, etc.), create additional redirect URIs in the same client:

1. Go to **Clients** → `theedgeworks` → **Settings**
2. Add to **Valid redirect URIs**:
   - MinIO: `https://storage-console.theedgeworks.ai/oauth_callback`
   - Harbor: `https://harbor.theedgeworks.ai/c/oidc/callback`
   - Longhorn: `https://longhorn.theedgeworks.ai/oauth2/callback`

## Security Notes

- Keep client secrets secure and never commit them to Git
- Use `use_pkce: true` for enhanced security
- Regularly rotate client secrets
- Review user access periodically in Keycloak

