# Infisical bootstrap secrets

These are created by hand, never committed. They are the root of trust for the
vault: **keep copies outside the cluster** (password manager). Losing
`ENCRYPTION_KEY` makes every stored secret and every database backup
unrecoverable.

| Secret | Keys | Purpose |
|---|---|---|
| `infisical-secrets` | `ENCRYPTION_KEY`, `AUTH_SECRET`, `DB_CONNECTION_URI`, `REDIS_URL`, `SITE_URL` | Read by the Infisical pods (`kubeSecretRef`) |
| `infisical-postgres` | `POSTGRES_PASSWORD` | Postgres superuser password; also used by the backup job |
| `infisical-redis` | `REDIS_PASSWORD` | Redis `requirepass` |
| `infisical-tls` | `tls.crt`, `tls.key` | Ingress cert for `vault.theedgeworks.ai`. Copied from the wildcard; renew with the other 7 copies |

Generation (`ENCRYPTION_KEY` must be 32 hex chars, i.e. 128 bit):

```bash
ENCRYPTION_KEY=$(openssl rand -hex 16)
AUTH_SECRET=$(openssl rand -base64 32)
PGPW=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 32)
REDISPW=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 32)

kubectl -n infisical create secret generic infisical-postgres --from-literal=POSTGRES_PASSWORD="$PGPW"
kubectl -n infisical create secret generic infisical-redis --from-literal=REDIS_PASSWORD="$REDISPW"
kubectl -n infisical create secret generic infisical-secrets \
  --from-literal=ENCRYPTION_KEY="$ENCRYPTION_KEY" \
  --from-literal=AUTH_SECRET="$AUTH_SECRET" \
  --from-literal=DB_CONNECTION_URI="postgresql://infisical:${PGPW}@infisical-postgres.infisical.svc.cluster.local:5432/infisical" \
  --from-literal=REDIS_URL="redis://:${REDISPW}@infisical-redis.infisical.svc.cluster.local:6379" \
  --from-literal=SITE_URL="https://vault.theedgeworks.ai"
```

## Restore
1. Recreate the secrets above with the **original** `ENCRYPTION_KEY`
   (the DB password may be new if the database is restored into a fresh one).
2. Restore a dump: `pg_restore -h infisical-postgres -U infisical -d infisical --clean --if-exists infisical-YYYY-MM-DD.dump`
3. Dumps live on PVC `infisical-backups` (14 days). They are not off-cluster yet.

## First login (admin takeover window)
Infisical makes the **first account to sign up the instance admin**. Do not
create the `vault.theedgeworks.ai` DNS record until you are ready to register
immediately, then create the admin account first and afterwards disable
sign-up (Admin console > Authentication) so nobody else can register.
