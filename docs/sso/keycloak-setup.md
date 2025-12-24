# Keycloak Configuration Guide

This guide covers setting up Keycloak for SSO authentication across all internal services.

## Prerequisites

- Keycloak server running at `https://auth.theedgeworks.ai`
- Admin access to Keycloak
- Google OAuth credentials (for Google Identity Provider)

## Step 1: Create Realm

1. Login to Keycloak Admin Console: `https://auth.theedgeworks.ai/admin/`
2. Click the realm dropdown (top-left) → **Create realm**
3. Set realm name: `theedgeworks`
4. Click **Create**

## Step 2: Configure Google Identity Provider

1. In the `theedgeworks` realm, go to **Identity providers**
2. Click **Add provider** → **Google**
3. Configure:

| Field | Value |
|-------|-------|
| Client ID | Your Google OAuth Client ID |
| Client Secret | Your Google OAuth Client Secret |
| First login flow | `first broker login` |

4. Click **Save**

### Google Cloud Console Setup

In Google Cloud Console, configure:
- **Authorized redirect URI**: `https://auth.theedgeworks.ai/realms/theedgeworks/broker/google/endpoint`

## Step 3: Create OIDC Client

1. Go to **Clients** → **Create client**

### General Settings
| Field | Value |
|-------|-------|
| Client type | OpenID Connect |
| Client ID | `theedgeworks` |

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
| Root URL | (leave empty) |
| Home URL | (leave empty) |
| Web origins | `https://*.theedgeworks.ai` |

#### Valid Redirect URIs
Add all service redirect URIs:
```
https://monitor.theedgeworks.ai/login/generic_oauth
https://storage-console.theedgeworks.ai/oauth_callback
https://harbor.theedgeworks.ai/c/oidc/callback
https://longhorn.theedgeworks.ai/oauth2/callback
```

#### Valid Post Logout Redirect URIs
Add all service logout redirect URIs:
```
https://monitor.theedgeworks.ai/login
https://storage-console.theedgeworks.ai
https://harbor.theedgeworks.ai
https://longhorn.theedgeworks.ai
```

Click **Save**

## Step 4: Get Client Secret

1. Go to **Clients** → `theedgeworks` → **Credentials** tab
2. Copy the **Client secret**
3. Store securely - needed for Kubernetes secrets

## Step 5: Configure Client Scopes

1. Go to **Clients** → `theedgeworks` → **Client scopes** tab
2. Verify these are in **Assigned default client scopes**:
   - `openid`
   - `email`
   - `profile`

If any are missing:
1. Click **Add client scope**
2. Select the missing scope
3. Click **Add** → **Default**

## Step 6: Create Groups Mapper (Optional - for Role-Based Access)

To enable role mapping based on Keycloak groups:

1. Go to **Clients** → `theedgeworks` → **Client scopes** tab
2. Click on `theedgeworks-dedicated`
3. Go to **Mappers** → **Add mapper** → **By configuration**
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

## Step 7: Create Groups

### Create Admin Group
1. Go to **Groups** (left menu)
2. Click **Create group**
3. Name: `grafana-admin` (or service-specific groups)
4. Click **Create**

### Assign Users to Groups
1. Go to **Users** → Select a user
2. Go to **Groups** tab
3. Click **Join Group**
4. Select the group
5. Click **Join**

## OIDC Endpoints Reference

| Endpoint | URL |
|----------|-----|
| Discovery | `https://auth.theedgeworks.ai/realms/theedgeworks/.well-known/openid-configuration` |
| Authorization | `https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/auth` |
| Token | `https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/token` |
| Userinfo | `https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/userinfo` |
| Logout | `https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/logout` |

## Troubleshooting

### Invalid redirect URI
- Verify the redirect URI in Keycloak matches exactly (including trailing slashes)
- Check for HTTP vs HTTPS mismatch

### User not found after login
- Ensure `email`, `profile`, and `openid` scopes are assigned
- Verify the groups mapper is configured correctly

### Groups not appearing in token
- Check "Add to userinfo" is enabled in the groups mapper
- Verify the user is actually assigned to the group

