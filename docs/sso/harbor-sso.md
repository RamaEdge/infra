# Harbor SSO Configuration

This guide covers configuring Harbor to authenticate via Keycloak OIDC.

## Prerequisites

- Keycloak realm and client configured (see [keycloak-setup.md](keycloak-setup.md))
- Client secret from Keycloak
- Harbor admin access

## Important Note

**Harbor OIDC is configured via the Web UI, not through Helm values.**

The Harbor Helm chart does not expose OIDC configuration as chart values. You must configure OIDC through the Harbor admin interface after deployment.

## Step 1: Login to Harbor Admin

1. Go to `https://harbor.theedgeworks.ai`
2. Login with admin credentials

## Step 2: Configure OIDC Authentication

1. Go to **Administration** → **Configuration**
2. Select **Authentication** tab
3. Set **Auth Mode** to **OIDC**
4. Configure:

| Field | Value |
|-------|-------|
| OIDC Provider Name | `Keycloak` |
| OIDC Endpoint | `https://auth.theedgeworks.ai/realms/theedgeworks` |
| OIDC Client ID | `theedgeworks` |
| OIDC Client Secret | (from Keycloak) |
| Group Claim Name | `groups` |
| OIDC Admin Group | `harbor-admin` (optional) |
| OIDC Scope | `openid,profile,email` |
| Verify Certificate | ✓ Checked |
| Automatic onboarding | ✓ Checked |
| Username Claim | `preferred_username` or `email` |

5. Click **Test OIDC Server** to verify connection
6. Click **Save**

## OIDC Settings Explanation

| Setting | Description |
|---------|-------------|
| OIDC Endpoint | Base URL of Keycloak realm (without `/protocol/...`) |
| Group Claim Name | JWT claim containing user groups |
| OIDC Admin Group | Keycloak group that grants Harbor admin |
| Automatic onboarding | Create Harbor user on first OIDC login |
| Username Claim | Which claim to use as Harbor username |

## Keycloak Redirect URI

Ensure this redirect URI is configured in Keycloak:
```
https://harbor.theedgeworks.ai/c/oidc/callback
```

## Role Mapping

Harbor uses Keycloak groups for role assignment:

| Keycloak Group | Harbor Role |
|----------------|-------------|
| `harbor-admin` | System Admin |
| (any authenticated) | Project access via RBAC |

### Create Harbor Admin Group in Keycloak

1. Go to Keycloak → **Groups**
2. Create group: `harbor-admin`
3. Add admin users to this group

## User Management

### First Login
When users first login via OIDC:
1. Harbor creates a local user account
2. Username is set from the configured claim
3. Email is populated from OIDC

### Project Access
OIDC users need to be added to projects:
1. Go to project → **Members**
2. Click **+ User**
3. Search for the OIDC username
4. Assign role (Guest, Developer, Maintainer, Admin)

## Troubleshooting

### OIDC Test Failed
- Verify OIDC Endpoint URL is correct (no trailing slash)
- Check client ID and secret
- Ensure Keycloak is reachable from Harbor

### User Not Created on Login
- Verify "Automatic onboarding" is enabled
- Check that required scopes (email, profile) are configured

### Groups Not Working
- Verify the groups mapper is configured in Keycloak
- Check Group Claim Name matches the mapper's Token Claim Name
- Ensure user is assigned to the group in Keycloak

### Check Harbor Logs
```bash
kubectl logs -n harbor -l app=harbor,component=core | grep -i oidc
```

## Docker CLI Authentication

For Docker CLI with OIDC, users need a CLI secret:

1. Login to Harbor web UI via OIDC
2. Go to user profile (top right)
3. Copy **CLI Secret**
4. Use for Docker login:
   ```bash
   docker login harbor.theedgeworks.ai -u <username>
   # Enter CLI secret as password
   ```

## Access

- **URL**: `https://harbor.theedgeworks.ai`
- **SSO Login**: Click "Login via OIDC Provider"
- **Docker Registry**: `harbor.theedgeworks.ai`

