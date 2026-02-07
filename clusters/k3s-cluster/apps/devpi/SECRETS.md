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

## 2. `devpi-basic-auth` — NGINX Basic Auth

Used by NGINX ingress to authenticate all requests (web UI, pip, twine) on all paths.

```bash
htpasswd -Bbn pypi-user <STRONG_PASSWORD> > /tmp/auth

kubectl create secret generic devpi-basic-auth \
  -n devpi \
  --from-file=auth=/tmp/auth

rm /tmp/auth
```
