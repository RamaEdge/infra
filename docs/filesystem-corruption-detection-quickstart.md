# Filesystem Corruption Detection - Quick Start

## Overview

This guide provides immediate steps to detect filesystem corruption in Harbor registry storage and other Longhorn volumes.

## Immediate Detection (Manual)

### Quick Health Check Script

Run this script to check Harbor storage health:

```bash
#!/bin/bash
# harbor-storage-check.sh

REGISTRY_POD=$(kubectl get pods -n harbor -l app=harbor,component=registry -o jsonpath='{.items[0].metadata.name}')
if [ -z "$REGISTRY_POD" ]; then
  echo "ERROR: No registry pod found"
  exit 1
fi

echo "=== Harbor Storage Health Check ==="
echo "Registry Pod: $REGISTRY_POD"
echo

# Test write
kubectl exec -n harbor "$REGISTRY_POD" -c registry -- \
  sh -c 'TEST_FILE="/storage/health-check-$$.test"; \
         if touch "$TEST_FILE" 2>&1; then \
           rm -f "$TEST_FILE"; \
           echo "✓ Write OK"; \
         else \
           echo "✗ Write FAILED"; \
           exit 1; \
         fi'

# Check for corrupted inodes
kubectl exec -n harbor "$REGISTRY_POD" -c registry -- \
  ls -la /storage/ | grep -q "^\?" && echo "✗ CORRUPTION DETECTED!" || echo "✓ No corruption"

# Check logs for I/O errors
echo
echo "Recent I/O errors:"
kubectl logs -n harbor "$REGISTRY_POD" -c registry --tail=100 | \
  grep -i "i/o error\|input/output error" | tail -5
```

## Automated Detection Setup

### Step 1: Deploy Storage Health Check CronJob

The health check CronJob runs every 15 minutes and tests storage integrity:

```bash
# Apply the health check CronJob
kubectl apply -f clusters/k3s-cluster/apps/harbor/storage-health-check.yaml

# Verify it's running
kubectl get cronjob -n harbor harbor-storage-health-check

# Check recent job status
kubectl get jobs -n harbor -l component=storage-health-check

# View logs from last run
kubectl logs -n harbor -l component=storage-health-check --tail=50
```

### Step 2: Deploy Prometheus Alerts

Add Prometheus alerting rules for filesystem corruption:

```bash
# Apply Prometheus alert rules
kubectl apply -f clusters/k3s-cluster/apps/harbor/prometheus-alerts.yaml

# Verify rules are loaded
kubectl get prometheusrule -n monitoring harbor-filesystem-corruption-alerts

# Check Prometheus UI for the rules
# Navigate to: http://prometheus.your-domain/alerts
```

### Step 3: Verify Monitoring

Check that metrics are being collected:

```bash
# Check Longhorn metrics (if Longhorn exposes metrics endpoint)
kubectl port-forward -n longhorn-system svc/longhorn-manager 8080:8080
curl http://localhost:8080/metrics | grep longhorn_volume

# Check Harbor registry metrics (if exposed)
kubectl port-forward -n harbor svc/harbor-harbor-registry 5000:5000
curl http://localhost:5000/metrics | grep harbor_registry
```

## What Gets Monitored

### 1. Storage Health Checks (Every 15 minutes)
- ✅ Write capability test
- ✅ Directory creation test
- ✅ Inode integrity check (detects `?????????` corruption)
- ✅ Filesystem mount status
- ✅ Disk space availability
- ✅ Read capability test

### 2. Prometheus Alerts
- 🚨 Harbor storage health check failures
- 🚨 Harbor registry 5xx write errors
- 🚨 Longhorn volume I/O errors
- 🚨 Longhorn volume unhealthy states
- 🚨 Longhorn replica failures
- 🚨 Kernel I/O errors

### 3. Log Monitoring
Monitor Harbor registry logs for:
- `input/output error`
- `I/O error`
- `filesystem.*error`
- `mkdir.*error`

## Alert Configuration

### Slack Integration Example

If using Prometheus Alertmanager with Slack:

```yaml
# alertmanager-config.yaml
receivers:
- name: 'critical-alerts'
  slack_configs:
  - channel: '#alerts'
    title: '🚨 {{ .GroupLabels.alertname }}'
    text: '{{ .CommonAnnotations.description }}'
    
route:
  routes:
  - match:
      severity: critical
    receiver: 'critical-alerts'
```

### Email Integration Example

```yaml
receivers:
- name: 'filesystem-alerts'
  email_configs:
  - to: 'ops-team@example.com'
    from: 'prometheus@example.com'
    subject: 'Filesystem Corruption Alert: {{ .GroupLabels.alertname }}'
    html: '{{ .CommonAnnotations.description }}'
```

## Response Playbook

When corruption is detected:

### Immediate Actions

1. **Stop writes** (if possible):
   ```bash
   # Scale down registry to prevent new writes
   kubectl scale deployment harbor-harbor-registry -n harbor --replicas=0
   ```

2. **Check volume status**:
   ```bash
   # Get PVC name
   PVC_NAME=$(kubectl get pvc -n harbor | grep registry | awk '{print $1}')
   
   # Get Longhorn volume name
   VOLUME_NAME=$(kubectl get pvc -n harbor "$PVC_NAME" -o jsonpath='{.spec.volumeName}')
   
   # Check volume status
   kubectl get volumes.longhorn.io "$VOLUME_NAME" -n longhorn-system -o yaml
   ```

3. **Check logs**:
   ```bash
   kubectl logs -n harbor -l app=harbor,component=registry --tail=200 | grep -i error
   ```

### Investigation

1. **Check Longhorn volume health**:
   ```bash
   kubectl describe volumes.longhorn.io <volume-name> -n longhorn-system
   ```

2. **Check node health**:
   ```bash
   # Get node where volume is attached
   NODE=$(kubectl get volumes.longhorn.io <volume-name> -n longhorn-system -o jsonpath='{.status.nodeID}')
   
   # Check node conditions
   kubectl describe node "$NODE"
   ```

3. **Check for hardware issues**:
   ```bash
   # On the node (requires SSH access)
   dmesg | grep -i "i/o error\|ext4.*error"
   ```

### Recovery Options

#### Option 1: Attempt Repair (Recommended First)

```bash
# Detach volume
kubectl patch volumes.longhorn.io <volume-name> -n longhorn-system \
  --type merge -p '{"spec":{"standby":true}}'

# Wait for detach
kubectl wait --for=jsonpath='{.status.state}'=detached \
  volumes.longhorn.io/<volume-name> -n longhorn-system --timeout=300s

# Create maintenance pod to run fsck
# (See full guide for detailed steps)
```

#### Option 2: Restore from Backup

```bash
# List available backups
kubectl get backups.longhorn.io -n longhorn-system

# Restore from backup
kubectl create -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  name: <volume-name>-restored
  namespace: longhorn-system
spec:
  fromBackup: <backup-url>
EOF
```

#### Option 3: Recreate PVC (Data Loss)

⚠️ **Warning**: This will lose all data in the volume.

```bash
# Backup any recoverable data first
# Then delete and recreate PVC
kubectl delete pvc harbor-harbor-registry -n harbor
# Recreate via HelmRelease or manually
```

## Prevention

1. **Enable Longhorn Backups**:
   ```bash
   # Configure backup target in Longhorn UI or via CRD
   kubectl apply -f - <<EOF
   apiVersion: longhorn.io/v1beta2
   kind: Setting
   metadata:
     name: backup-target
     namespace: longhorn-system
   value: "s3://backup-bucket@us-east-1/"
   EOF
   ```

2. **Use Multiple Replicas**:
   - Configure Longhorn volumes with 2-3 replicas
   - Distribute replicas across different nodes

3. **Regular Maintenance**:
   - Schedule weekly fsck checks during maintenance windows
   - Monitor disk health on nodes

4. **Resource Limits**:
   - Ensure pods have proper resource limits
   - Prevent OOM kills that can corrupt filesystems

## Troubleshooting

### Health Check Job Failing

```bash
# Check job logs
kubectl logs -n harbor -l component=storage-health-check --tail=100

# Check job status
kubectl describe job -n harbor -l component=storage-health-check
```

### Prometheus Alerts Not Firing

```bash
# Check if rules are loaded
kubectl get prometheusrule -n monitoring

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Navigate to http://localhost:9090/rules
```

### Longhorn Metrics Not Available

Longhorn metrics may require additional configuration. Check Longhorn documentation for metrics setup.

## References

- Full Detection Guide: `docs/filesystem-corruption-detection.md`
- Harbor Configuration: `.cursor/rules/harbor-config.mdc`
- Longhorn Documentation: https://longhorn.io/docs/

