# devpi Secrets

All secrets must be created in the `devpi` namespace before Flux reconciliation.

```bash
kubectl create namespace devpi
```

## 1. `devpi-tls` — TLS Certificate

TLS certificate for `pypi.theedgeworks.ai`.

```bash
kubectl create secret tls devpi-tls \
  -n devpi \
  --cert=/path/to/cert.crt \
  --key=/path/to/key.key
```

## 2. `devpi-secret` — Server Token Signing Key

Used by devpi-server (`--secretfile`) to sign login tokens. Without a persistent secret, every pod restart invalidates all `devpi login` sessions.

```bash
SECRET=$(python3 -c 'import os,base64; print(base64.b64encode(os.urandom(32)).decode())')

kubectl create secret generic devpi-secret \
  -n devpi \
  --from-literal=secret="${SECRET}"
```

## 3. `devpi-oauth2-proxy-secret` — Keycloak OIDC Credentials

Used by the dedicated oauth2-proxy instance for Keycloak authentication on the web UI.

- `client-id`: Keycloak client ID (`theedgeworks`)
- `client-secret`: Keycloak client secret (from Keycloak admin console → Clients → `theedgeworks` → Credentials)
- `cookie-secret`: Random secret for encrypting oauth2-proxy session cookies

```bash
COOKIE_SECRET=$(python3 -c 'import os,base64; print(base64.b64encode(os.urandom(32)).decode())')

kubectl create secret generic devpi-oauth2-proxy-secret \
  -n devpi \
  --from-literal=client-id=theedgeworks \
  --from-literal=client-secret=<CLIENT_SECRET_FROM_KEYCLOAK> \
  --from-literal=cookie-secret="${COOKIE_SECRET}"
```

## 4. `devpi-basic-auth` — NGINX Basic Auth for pip/twine

Used by NGINX ingress to authenticate CLI tools (pip, twine) on API paths (`/root/`, `/upload/`, `/+api`, `/+login`).

```bash
htpasswd -Bbn pypi-user <STRONG_PASSWORD> > /tmp/auth

kubectl create secret generic devpi-basic-auth \
  -n devpi \
  --from-file=auth=/tmp/auth

rm /tmp/auth
```

## Keycloak Configuration

In addition to the secrets above, update the Keycloak `theedgeworks` client:

1. Add `https://pypi.theedgeworks.ai/oauth2/callback` to **Valid Redirect URIs**
2. Add `https://pypi.theedgeworks.ai` to **Web Origins**
