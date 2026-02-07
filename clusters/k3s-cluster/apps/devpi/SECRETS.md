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

## 2. `devpi-upload-secret` — Upload User Password

Password for the devpi upload user. The entrypoint script reads this at startup and automatically creates the user and `<user>/packages` index inside devpi.

The username defaults to `upload`. To use a different name, set the `DEVPI_UPLOAD_USER` env var in the deployment.

```bash
kubectl create secret generic devpi-upload-secret \
  -n devpi \
  --from-literal=password=<DEVPI_UPLOAD_PASSWORD>
```

## 3. `devpi-basic-auth` — NGINX Basic Auth

Used by NGINX ingress to authenticate all requests (web UI, pip, twine) on all paths.

The `upload` user **must** appear in this htpasswd file with the **same password** as `devpi-upload-secret` so that NGINX passes the request through and devpi also accepts it.

```bash
htpasswd -Bbn pypi-user <PIP_PASSWORD> > /tmp/auth
htpasswd -Bbn upload <DEVPI_UPLOAD_PASSWORD> >> /tmp/auth

kubectl create secret generic devpi-basic-auth \
  -n devpi \
  --from-file=auth=/tmp/auth

rm /tmp/auth
```

Then use **TWINE_USERNAME=upload** and **TWINE_PASSWORD=<DEVPI_UPLOAD_PASSWORD>** for `make push-devpi` and in GitHub Actions (DEVPY_USERNAME/DEVPY_PASSWORD).
