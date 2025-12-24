# Single Sign-On (SSO) Documentation

This directory contains documentation for configuring Keycloak-based SSO for all internal services.

## Overview

All internal services authenticate through Keycloak, which uses Google as the Identity Provider. This provides:
- Centralized authentication
- Single Sign-On across all services
- Role-based access control via Keycloak groups

## Architecture

```
                    ┌─────────────────┐
                    │  Google OAuth   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │    Keycloak     │
                    │ (theedgeworks   │
                    │     realm)      │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   ┌─────────┐         ┌─────────┐         ┌─────────┐
   │ Grafana │         │  MinIO  │         │ Harbor  │
   └─────────┘         └─────────┘         └─────────┘
```

## Documentation

| Document | Description |
|----------|-------------|
| [keycloak-setup.md](keycloak-setup.md) | Keycloak realm, client, and groups configuration |
| [grafana-sso.md](grafana-sso.md) | Grafana OIDC configuration |
| [harbor-sso.md](harbor-sso.md) | Harbor OIDC configuration |
| [minio-sso.md](minio-sso.md) | MinIO OIDC configuration |

## Quick Reference

### Keycloak URLs
- Admin Console: `https://auth.theedgeworks.ai/admin/`
- Realm: `theedgeworks`
- OIDC Discovery: `https://auth.theedgeworks.ai/realms/theedgeworks/.well-known/openid-configuration`

### Service URLs
| Service | URL |
|---------|-----|
| Grafana | `https://monitor.theedgeworks.ai` |
| MinIO Console | `https://storage-console.theedgeworks.ai` |
| Harbor | `https://harbor.theedgeworks.ai` |

### Client Configuration
- **Client ID**: `theedgeworks`
- **Client Type**: Confidential (requires secret)
- **Scopes**: `openid profile email`

