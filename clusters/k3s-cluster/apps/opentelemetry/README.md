# OpenTelemetry Configuration

This directory contains the Flux configuration to deploy OpenTelemetry from an external repository.

## Setup Instructions

1. **Update the GitRepository URL** in `source.yaml` to point to your actual OpenTelemetry manifests repository
2. **Adjust the path** in `kustomization.yaml` to match the directory structure in your OpenTelemetry repository
3. **Apply the configuration** using Flux

## Current Configuration

- **Source Repository**: Update `source.yaml` with the correct repository URL
- **Target Namespace**: `opentelemetry-system`
- **Sync Interval**: 10 minutes
