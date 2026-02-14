# Forgejo

Forgejo is deployed on the k3s cluster via Flux CD, with PostgreSQL as the database and Keycloak for OIDC authentication.

## Architecture

- **Forgejo**: Git hosting (Helm chart from code.forgejo.org)
- **PostgreSQL**: Bitnami PostgreSQL (dedicated instance for Forgejo)
- **Keycloak**: Existing cluster Keycloak at `https://auth.theedgeworks.ai`, realm `theedgeworks`

## Prerequisites

1. Create the required secrets in the `forgejo` namespace (see below)
2. Create a Forgejo client in Keycloak
3. Configure DNS for `forgejo.theedgeworks.ai` to point to the ingress

## Required Secrets

Create these secrets **before** or shortly after deployment. They are not stored in Git.

### forgejo-db-credentials

PostgreSQL credentials for the Forgejo database user.

```bash
kubectl create secret generic forgejo-db-credentials -n forgejo \
  --from-literal=username=forgejo \
  --from-literal=password=<secure-password> \
  --from-literal=postgres-password=<admin-password>
```

### forgejo-admin-secret

Forgejo admin user (used for initial setup and recovery).

```bash
kubectl create secret generic forgejo-admin-secret -n forgejo \
  --from-literal=username=forgejo_admin \
  --from-literal=password=<admin-password> \
  --from-literal=email=admin@example.com
```

### forgejo-oidc-secret

Keycloak OIDC client credentials. Create after setting up the Forgejo client in Keycloak.

```bash
kubectl create secret generic forgejo-oidc-secret -n forgejo \
  --from-literal=key=forgejo \
  --from-literal=secret=<keycloak-client-secret>
```

### forgejo-tls

TLS certificate for `forgejo.theedgeworks.ai`. Or reuse an existing wildcard secret if applicable.

```bash
kubectl create secret tls forgejo-tls -n forgejo \
  --cert=/path/to/cert.crt \
  --key=/path/to/key.key
```

## Keycloak Client Setup

1. Log in to Keycloak Admin at `https://auth.theedgeworks.ai/admin/theedgeworks/console/`
2. Go to **Clients** → **Create client**
3. **Client ID**: `forgejo`
4. **Client authentication**: On
5. **Root URL**: `https://forgejo.theedgeworks.ai`
6. **Valid redirect URIs**: `https://forgejo.theedgeworks.ai/*`
7. **Web origins**: `https://forgejo.theedgeworks.ai`
8. Save and copy the **Client secret** for `forgejo-oidc-secret`

## Verification

```bash
# Check Flux reconciliation
flux get helmreleases -n flux-system | grep forgejo

# Check pods
kubectl get pods -n forgejo

# Check ingress
kubectl get ingress -n forgejo
```

## Troubleshooting

### OIDC redirect errors

- Ensure redirect URIs in Keycloak exactly match `https://forgejo.theedgeworks.ai/*`
- Verify `forgejo-oidc-secret` has correct `key` (client ID) and `secret` (client secret)

### Database connection failures

- Ensure `forgejo-db-credentials` exists before the Forgejo pod starts
- Check PostgreSQL is ready: `kubectl get pods -n forgejo -l app.kubernetes.io/name=postgresql`

### Pod not starting

- Check logs: `kubectl logs -n forgejo -l app.kubernetes.io/name=forgejo -f`
- Verify all required secrets exist: `kubectl get secrets -n forgejo`
