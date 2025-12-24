# Grafana SSO Configuration

This guide covers configuring Grafana to authenticate via Keycloak OIDC.

## Prerequisites

- Keycloak realm and client configured (see [keycloak-setup.md](keycloak-setup.md))
- Client secret from Keycloak

## Step 1: Create Kubernetes Secret

Create the secret in the `monitoring` namespace:

```bash
kubectl create secret generic keycloak-oidc \
  -n monitoring \
  --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET='YOUR_CLIENT_SECRET'
```

Replace `YOUR_CLIENT_SECRET` with the client secret from Keycloak.

### Verify Secret
```bash
kubectl get secret keycloak-oidc -n monitoring
```

## Step 2: HelmRelease Configuration

The Grafana configuration is in `clusters/k3s-cluster/apps/kube-prometheus-stack/helmrelease.yaml`.

### Key Configuration

```yaml
grafana:
  # Load client secret from Kubernetes secret
  envFromSecrets:
    - name: keycloak-oidc

  grafana.ini:
    server:
      domain: monitor.theedgeworks.ai
      root_url: https://monitor.theedgeworks.ai
    
    auth:
      disable_login_form: false  # Set to true to force SSO only
      oauth_allow_insecure_email_lookup: true
    
    auth.basic:
      enabled: true  # Set to false to disable basic auth
    
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
      signout_redirect_url: https://auth.theedgeworks.ai/realms/theedgeworks/protocol/openid-connect/logout?post_logout_redirect_uri=https%3A%2F%2Fmonitor.theedgeworks.ai%2Flogin
      email_attribute_path: email
      login_attribute_path: email
      name_attribute_path: name
```

### Role Mapping (Optional)

To map Keycloak groups to Grafana roles, add:

```yaml
auth.generic_oauth:
  # ... other settings ...
  groups_attribute_path: groups
  role_attribute_path: contains(groups[*], 'grafana-admin') && 'Admin' || 'Viewer'
```

| Keycloak Group | Grafana Role |
|----------------|--------------|
| `grafana-admin` | Admin |
| (none) | Viewer |

To add Editor role:
```yaml
role_attribute_path: contains(groups[*], 'grafana-admin') && 'Admin' || contains(groups[*], 'grafana-editor') && 'Editor' || 'Viewer'
```

## Configuration Options

| Setting | Description | Recommended |
|---------|-------------|-------------|
| `disable_login_form` | Hide username/password form | `false` (keep as fallback) |
| `oauth_allow_insecure_email_lookup` | Allow email-based user lookup | `true` (required) |
| `allow_sign_up` | Auto-create users on first login | `true` |
| `use_pkce` | Use PKCE for enhanced security | `true` |

## Applying Changes

After modifying the HelmRelease:

```bash
# Commit and push
git add -A && git commit -m "Update Grafana SSO config" && git push

# Reconcile Flux
flux reconcile source git infra
flux reconcile helmrelease kube-prometheus-stack -n monitoring
```

## Troubleshooting

### User sync failed
```
error="user not found" auth_module=oauth_generic_oauth
```

**Solution**: Ensure `oauth_allow_insecure_email_lookup: true` is set.

### Check logs
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana | grep -i oauth
```

### Verify configuration
```bash
kubectl exec -n monitoring <grafana-pod> -c grafana -- cat /etc/grafana/grafana.ini | grep -A 20 "auth.generic_oauth"
```

## Access

- **URL**: `https://monitor.theedgeworks.ai`
- **SSO Login**: Click "Sign in with Keycloak"
- **Basic Auth**: Use admin credentials if enabled

