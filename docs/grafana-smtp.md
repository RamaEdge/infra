# Grafana SMTP via Google Workspace Relay

Grafana sends alert emails via Google Workspace's SMTP Relay Service so we can use any `From` address on the `theedgeworks.ai` domain (e.g. `alerts@theedgeworks.ai`) without provisioning a dedicated mailbox.

## Architecture

```
Grafana ──(STARTTLS, SMTP AUTH)──► smtp-relay.gmail.com:587
                                          │
                                          └──► relays as alerts@theedgeworks.ai
```

- **Auth user**: `ravichillerega@theedgeworks.ai` (existing Workspace user)
- **Auth secret**: 16-character Google App Password (rotatable, scoped to mail)
- **Sender identity**: `alerts@theedgeworks.ai` (no mailbox required, allowed because the relay is configured for the domain)

## Step 1: Workspace Admin Console — SMTP Relay Service

One-time setup at https://admin.google.com → Apps → Google Workspace → Gmail → Routing.

1. Click **Configure** under **SMTP Relay Service**.
2. Add a new entry:
   - **Name**: `Grafana Alerts`
   - **Allowed senders**: *Only addresses in my domains*
   - **Authentication**: ✅ *Require SMTP Authentication*
   - **Encryption**: ✅ *Require TLS encryption*
3. Save.

## Step 2: Generate App Password

1. Go to https://myaccount.google.com/apppasswords (signed in as `ravichillerega@theedgeworks.ai`).
2. App: **Mail**, Device: **Other (Grafana SMTP)**.
3. Copy the 16-character password — it is shown only once.

## Step 3: Create Kubernetes Secret

The secret is **not** stored in git. Create it manually:

```bash
kubectl create secret generic grafana-smtp \
  -n monitoring \
  --from-literal=GF_SMTP_PASSWORD='YOUR_16_CHAR_APP_PASSWORD'
```

Verify:

```bash
kubectl get secret grafana-smtp -n monitoring
```

To rotate later: delete and recreate, then restart the Grafana pod
(`kubectl rollout restart deploy/kube-prometheus-stack-grafana -n monitoring`).

## Step 4: HelmRelease Configuration

Already in `clusters/k3s-cluster/apps/kube-prometheus-stack/helmrelease.yaml`:

```yaml
grafana:
  envFromSecrets:
    - name: keycloak-oidc
    - name: grafana-smtp        # ← provides GF_SMTP_PASSWORD

  grafana.ini:
    smtp:
      enabled: true
      host: smtp-relay.gmail.com:587
      user: ravichillerega@theedgeworks.ai
      from_address: alerts@theedgeworks.ai
      from_name: Grafana Alerts
      startTLS_policy: MandatoryStartTLS
      skip_verify: false
```

`GF_SMTP_PASSWORD` from the secret overrides any password set in `grafana.ini`.

## Step 5: Apply and Verify

Flux will reconcile the HelmRelease. Or push and wait, or:

```bash
flux reconcile helmrelease kube-prometheus-stack -n monitoring
kubectl rollout restart deploy/kube-prometheus-stack-grafana -n monitoring
```

Test from the Grafana UI:

1. Navigate to **Alerting → Contact points**.
2. Create or edit an Email contact point.
3. Click **Test** — you should receive the test email at the configured address.

If the test fails, check logs:

```bash
kubectl logs -n monitoring deploy/kube-prometheus-stack-grafana -c grafana | grep -i smtp
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `535 5.7.8 Username and Password not accepted` | App password wrong, or 2-Step Verification not enabled on the user |
| `530 5.7.0 Must issue a STARTTLS command first` | `startTLS_policy` not set or `skip_verify: true` |
| `550 5.7.1 ... not authorized to use this MTA` | Sender address outside `theedgeworks.ai`, or the relay isn't configured for the domain |
| Test passes but production alerts never arrive | Contact point not attached to an alert rule, or notification policy routes to a different contact point |

## Sending Limits

- 10,000 recipients/day per authenticated user (the relay limit).
- One alert email = one recipient. Even at high alert volume this is plenty.
