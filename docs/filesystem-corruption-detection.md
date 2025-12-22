# Filesystem Corruption Detection Guide

## Overview

This guide provides strategies for proactively detecting filesystem corruption in Kubernetes persistent volumes, with specific focus on Longhorn volumes and Harbor registry storage.

## Detection Strategies

### 1. Application-Level Detection

#### Registry Write Health Checks

Create a Kubernetes CronJob that periodically tests write operations to detect corruption early:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: harbor-storage-health-check
  namespace: harbor
spec:
  schedule: "*/15 * * * *"  # Every 15 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: health-check
            image: busybox:latest
            command:
            - /bin/sh
            - -c
            - |
              # Test write capability
              TEST_FILE="/storage/health-check-$(date +%s).test"
              if ! touch "$TEST_FILE" 2>&1; then
                echo "ERROR: Failed to write test file: $TEST_FILE"
                exit 1
              fi
              
              # Test directory creation
              TEST_DIR="/storage/health-check-dir-$(date +%s)"
              if ! mkdir "$TEST_DIR" 2>&1; then
                echo "ERROR: Failed to create test directory: $TEST_DIR"
                exit 1
              fi
              
              # Cleanup
              rm -f "$TEST_FILE"
              rmdir "$TEST_DIR" 2>/dev/null || true
              
              # Check for corrupted inodes (directories with ? marks)
              if ls -la /storage/ | grep -q "^\?"; then
                echo "ERROR: Detected corrupted inodes in /storage"
                exit 1
              fi
              
              echo "OK: Storage health check passed"
            volumeMounts:
            - name: registry-storage
              mountPath: /storage
          volumes:
          - name: registry-storage
            persistentVolumeClaim:
              claimName: harbor-harbor-registry
          restartPolicy: OnFailure
```

#### Harbor Registry Readiness Probe Enhancement

Add a custom readiness probe that validates storage health:

```yaml
# Patch for Harbor registry deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: harbor-harbor-registry
  namespace: harbor
spec:
  template:
    spec:
      containers:
      - name: registry
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - |
              # Test write capability
              TEST_FILE="/storage/.readiness-probe-$$"
              if ! touch "$TEST_FILE" 2>&1; then
                echo "Storage write test failed"
                exit 1
              fi
              rm -f "$TEST_FILE"
              
              # Check registry endpoint
              wget -q --spider http://localhost:5000/v2/ || exit 1
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
```

### 2. Longhorn Volume Monitoring

#### Prometheus Metrics

Longhorn exposes metrics that can be monitored:

```yaml
# ServiceMonitor for Longhorn
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: longhorn-metrics
  namespace: longhorn-system
spec:
  selector:
    matchLabels:
      app: longhorn-manager
  endpoints:
  - port: manager
    interval: 30s
    path: /metrics
```

#### Key Metrics to Alert On

```promql
# Volume I/O errors
longhorn_volume_io_error_total > 0

# Volume state not healthy
longhorn_volume_state{state!="attached"} == 1

# Replica rebuild failures
longhorn_replica_rebuild_failure_total > 0

# Engine state issues
longhorn_engine_state{state!="running"} == 1

# Volume actual size mismatch (potential corruption)
(longhorn_volume_actual_size_bytes - longhorn_volume_size_bytes) / longhorn_volume_size_bytes > 0.1
```

### 3. Prometheus Alerting Rules

Create alert rules for filesystem corruption:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: filesystem-corruption-alerts
  namespace: monitoring
spec:
  groups:
  - name: filesystem.corruption
    interval: 30s
    rules:
    # Alert on I/O errors in Longhorn volumes
    - alert: LonghornVolumeIOError
      expr: rate(longhorn_volume_io_error_total[5m]) > 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Longhorn volume I/O errors detected"
        description: "Volume {{ $labels.volume }} has I/O errors: {{ $value }} errors/sec"
    
    # Alert on unhealthy volume states
    - alert: LonghornVolumeUnhealthy
      expr: longhorn_volume_state{state!="attached"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Longhorn volume is not attached"
        description: "Volume {{ $labels.volume }} is in state {{ $labels.state }}"
    
    # Alert on registry write failures
    - alert: HarborRegistryWriteFailure
      expr: increase(harbor_registry_http_requests_total{method="PUT",code=~"5.."}[5m]) > 0
      for: 3m
      labels:
        severity: critical
      annotations:
        summary: "Harbor registry write failures detected"
        description: "Registry is returning 5xx errors on PUT requests: {{ $value }} failures"
    
    # Alert on storage health check failures
    - alert: HarborStorageHealthCheckFailed
      expr: kube_job_status_failed{job_name=~"harbor-storage-health-check-.*"} > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Harbor storage health check failed"
        description: "Storage health check job {{ $labels.job_name }} failed"
    
    # Alert on kernel I/O errors (requires node exporter)
    - alert: KernelIOError
      expr: node_disk_io_now{device!~"dm-.*"} > 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Kernel I/O errors detected on disk"
        description: "Disk {{ $labels.device }} on {{ $labels.instance }} has I/O errors"
```

### 4. Log-Based Detection

#### Harbor Registry Log Monitoring

Monitor registry logs for I/O errors:

```yaml
# LogQL query for Loki
{namespace="harbor", pod=~"harbor-harbor-registry-.*"} 
  |= "error" 
  |~ "input/output error|I/O error|filesystem.*error|mkdir.*error"
```

#### Prometheus Alert from Logs

```yaml
- alert: HarborRegistryIOError
  expr: |
    sum(rate({namespace="harbor", pod=~"harbor-harbor-registry-.*"} 
      |~ "input/output error|I/O error" [5m])) > 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Harbor registry I/O errors in logs"
    description: "Registry logs show I/O errors: {{ $value }} errors/sec"
```

### 5. Kubernetes Health Checks

#### Custom Storage Validator

Create a DaemonSet that validates storage on each node:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: storage-validator
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: storage-validator
  template:
    metadata:
      labels:
        app: storage-validator
    spec:
      containers:
      - name: validator
        image: busybox:latest
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            # Check for filesystem errors in dmesg
            dmesg | grep -i "i/o error\|ext4.*error\|buffer.*error" | tail -10
            
            # Check mount points
            mount | grep -E "longhorn|ext4" | while read line; do
              MOUNT=$(echo $line | awk '{print $3}')
              if [ ! -w "$MOUNT" ]; then
                echo "ERROR: $MOUNT is not writable"
              fi
            done
            
            sleep 300
          done
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-proc
          mountPath: /host/proc
          readOnly: true
        - name: host-sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: host-proc
        hostPath:
          path: /proc
      - name: host-sys
        hostPath:
          path: /sys
```

### 6. Application-Level Monitoring

#### Harbor Registry Metrics

Monitor registry-specific metrics:

```promql
# Registry request errors
rate(harbor_registry_http_requests_total{code=~"5.."}[5m])

# Registry storage operations
rate(harbor_registry_storage_operations_total{operation="write",status="error"}[5m])

# Registry blob operations
rate(harbor_registry_blob_operations_total{operation="put",status="error"}[5m])
```

### 7. Automated Filesystem Checks

#### Periodic fsck Validation

Create a CronJob that runs filesystem checks:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: longhorn-volume-fsck
  namespace: longhorn-system
spec:
  schedule: "0 2 * * 0"  # Weekly on Sunday at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: fsck
            image: longhornio/longhorn-engine:v1.10.1
            command:
            - /bin/sh
            - -c
            - |
              # List all Longhorn volumes
              kubectl get volumes.longhorn.io -n longhorn-system -o json | \
                jq -r '.items[] | select(.status.state == "attached") | .metadata.name' | \
                while read volume; do
                  echo "Checking volume: $volume"
                  
                  # Detach volume for fsck
                  kubectl patch volumes.longhorn.io "$volume" -n longhorn-system \
                    --type merge -p '{"spec":{"standby":true}}'
                  
                  # Wait for detach
                  kubectl wait --for=jsonpath='{.status.state}'=detached \
                    volumes.longhorn.io/"$volume" -n longhorn-system --timeout=300s
                  
                  # Run fsck (requires access to Longhorn engine)
                  # Note: This is a simplified example - actual fsck requires
                  # mounting the volume or using Longhorn's maintenance mode
                  
                  # Reattach volume
                  kubectl patch volumes.longhorn.io "$volume" -n longhorn-system \
                    --type merge -p '{"spec":{"standby":false}}'
                done
          serviceAccountName: longhorn-service-account
          # Requires RBAC permissions to manage Longhorn volumes
```

### 8. Early Warning Indicators

#### Monitor These Metrics

1. **I/O Error Rate**: Track `longhorn_volume_io_error_total`
2. **Write Latency**: Monitor `longhorn_volume_write_latency_seconds`
3. **Volume State Changes**: Alert on `longhorn_volume_state` transitions
4. **Replica Health**: Monitor `longhorn_replica_state`
5. **Application Errors**: Track 5xx errors from registry API
6. **Storage Health Check Failures**: Monitor CronJob failures

### 9. Manual Detection Commands

#### Quick Health Check Script

```bash
#!/bin/bash
# harbor-storage-check.sh

echo "=== Harbor Storage Health Check ==="
echo "Date: $(date)"
echo

# Check registry pod
REGISTRY_POD=$(kubectl get pods -n harbor -l app=harbor,component=registry -o jsonpath='{.items[0].metadata.name}')
if [ -z "$REGISTRY_POD" ]; then
  echo "ERROR: No registry pod found"
  exit 1
fi

echo "Registry Pod: $REGISTRY_POD"
echo

# Test write capability
echo "Testing write capability..."
kubectl exec -n harbor "$REGISTRY_POD" -c registry -- \
  sh -c 'TEST_FILE="/storage/health-check-$$.test"; \
         if touch "$TEST_FILE" 2>&1; then \
           rm -f "$TEST_FILE"; \
           echo "✓ Write test passed"; \
         else \
           echo "✗ Write test failed"; \
           exit 1; \
         fi'

# Check for corrupted inodes
echo "Checking for corrupted inodes..."
kubectl exec -n harbor "$REGISTRY_POD" -c registry -- \
  ls -la /storage/ | grep -q "^\?" && echo "✗ Corrupted inodes detected!" || echo "✓ No corrupted inodes"

# Check Longhorn volume status
PVC_NAME="harbor-harbor-registry"
VOLUME_NAME=$(kubectl get pvc -n harbor "$PVC_NAME" -o jsonpath='{.spec.volumeName}')
if [ -n "$VOLUME_NAME" ]; then
  echo
  echo "Longhorn Volume: $VOLUME_NAME"
  kubectl get volumes.longhorn.io "$VOLUME_NAME" -n longhorn-system -o jsonpath='{.status}' | jq .
fi

# Check for I/O errors in logs
echo
echo "Recent I/O errors in registry logs:"
kubectl logs -n harbor "$REGISTRY_POD" -c registry --tail=100 | \
  grep -i "i/o error\|input/output error\|filesystem.*error" | tail -5

echo
echo "=== Health Check Complete ==="
```

### 10. Integration with Existing Monitoring

#### PrometheusRules Already Deployed

The following PrometheusRules are deployed in `clusters/k3s-cluster/apps/kube-prometheus-stack/`:

- **`prometheusrule-harbor.yaml`**: Harbor Core, Registry, Database, JobService, Trivy alerts
- **`prometheusrule-nginx-ingress.yaml`**: NGINX Ingress errors, latency, SSL, config alerts  
- **`prometheusrule-longhorn.yaml`**: Longhorn volume, replica, node, backup, engine alerts

These rules monitor for the corruption scenarios described in this guide, including:
- Registry storage write errors
- Manifest upload failures (the error we encountered)
- Longhorn volume degradation and I/O errors
- Filesystem corruption indicators

### 11. Recommended Alerting Channels

- **Critical**: Immediate notification (PagerDuty, Slack #alerts)
- **Warning**: Daily digest (Email, Slack #monitoring)
- **Info**: Weekly summary (Email)

## Prevention Strategies

1. **Regular Backups**: Ensure Longhorn backups are configured
2. **Volume Replication**: Use multiple replicas for critical volumes
3. **Graceful Shutdowns**: Ensure pods shut down gracefully
4. **Resource Limits**: Prevent OOM kills that can corrupt filesystems
5. **Regular Maintenance**: Schedule periodic fsck checks during maintenance windows

## Response Playbook

When corruption is detected:

1. **Immediate**: Stop writes to affected volume
2. **Investigate**: Check Longhorn volume status and logs
3. **Isolate**: Detach volume if possible
4. **Repair**: Attempt fsck repair
5. **Restore**: If repair fails, restore from backup
6. **Document**: Record root cause and prevention measures

## References

- [Longhorn Monitoring](https://longhorn.io/docs/1.5.0/monitoring/metrics/)
- [Harbor Troubleshooting](https://goharbor.io/docs/latest/administration/troubleshooting/)
- [Kubernetes Volume Health](https://kubernetes.io/docs/concepts/storage/volumes/#volume-health-monitoring)

