# Google Workspace OIDC Authentication Setup

This document provides step-by-step instructions for setting up Google Workspace OIDC authentication for MinIO and Harbor.

## Prerequisites

- Google Workspace admin access
- Kubernetes cluster with MinIO and Harbor deployed
- kubectl access to the cluster

## Step 1: Google Workspace Admin Console Setup

### 1.1 Configure OAuth Consent Screen

1. Go to [Google Admin Console](https://admin.google.com/)
2. Navigate to **Security** → **API Controls**
3. Go to **OAuth consent screen**
4. Configure the following:
   - **App name**: "MinIO & Harbor Authentication"
   - **User support email**: Your admin email
   - **Developer contact**: Your email
   - **Scopes**: Add the following scopes:
     - `openid`
     - `profile`
     - `email`

### 1.2 Create OAuth 2.0 Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Google Workspace project (should be auto-created)
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth 2.0 Client ID**
5. Configure:
   - **Application type**: Web application
   - **Name**: "MinIO Harbor OIDC"
   - **Authorized redirect URIs**:
     ```
     https://minio-console.theedgeworks.ai/oauth_callback
     https://harbor.theedgeworks.ai/c/oidc/callback
     ```
   - **Authorized JavaScript origins**:
     ```
     https://minio-console.theedgeworks.ai
     https://harbor.theedgeworks.ai
     ```

6. **Save** and note down the **Client ID** and **Client Secret**

### 1.3 Configure Domain Restrictions (Optional)

1. In Google Admin Console, go to **Security** → **API Controls**
2. Go to **Domain-wide delegation**
3. Add your OAuth client ID
4. Grant the following scopes:
   ```
   https://www.googleapis.com/auth/userinfo.email
   https://www.googleapis.com/auth/userinfo.profile
   https://www.googleapis.com/auth/openid
   ```

## Step 2: Create Kubernetes Secrets

### 2.1 MinIO Google Workspace OIDC Secret

```bash
kubectl create secret generic minio-google-workspace-oidc \
  --from-literal=client-id="YOUR_GOOGLE_CLIENT_ID" \
  --from-literal=client-secret="YOUR_GOOGLE_CLIENT_SECRET" \
  -n minio-tenant
```

### 2.2 Harbor Google Workspace OIDC Secret

```bash
kubectl create secret generic harbor-google-workspace-oidc \
  --from-literal=client-id="YOUR_GOOGLE_CLIENT_ID" \
  --from-literal=client-secret="YOUR_GOOGLE_CLIENT_SECRET" \
  -n harbor
```

## Step 3: Deploy Configuration

The Harbor configuration now uses secret references for the client ID and client secret:

```yaml
# In clusters/k3s-cluster/apps/harbor/helmrelease.yaml
oidc:
  name: "Google Workspace"
  endpoint: "https://accounts.google.com"
  clientIdSecretRef:
    name: harbor-google-workspace-oidc
    key: client-id
  clientSecretSecretRef:
    name: harbor-google-workspace-oidc
    key: client-secret
  scope: "openid,profile,email"
  verifyCert: true
  autoOnboard: true
  extraRedirectParms:
    scope: "openid,profile,email"
    hd: "theedgeworks.ai"
```

Deploy the changes:

```bash
# Commit and push changes
git add .
git commit -m "Add Google Workspace OIDC authentication for MinIO and Harbor"
git push origin main

# Monitor deployment
kubectl get pods -n minio-tenant
kubectl get pods -n harbor
```

## Step 4: Testing

### 4.1 Test MinIO Console

1. Go to `https://minio-console.theedgeworks.ai`
2. Click "Login with Google"
3. Complete Google OAuth flow
4. Verify successful login with your Google Workspace account

### 4.2 Test Harbor

1. Go to `https://harbor.theedgeworks.ai`
2. Click "Login with Google"
3. Complete Google OAuth flow
4. Verify successful login and auto-onboarding

### 4.3 Test Domain Restriction

1. Try logging in with a personal Gmail account
2. Should be rejected if domain restriction is working
3. Only users from your Google Workspace domain should be able to authenticate

## Troubleshooting

### Common Issues

1. **"Invalid redirect URI" error**:
   - Verify the redirect URIs in Google Cloud Console match exactly
   - Check for trailing slashes or HTTP vs HTTPS

2. **"Access denied" error**:
   - Verify the OAuth consent screen is configured
   - Check if the user is from the correct domain (if domain restriction is enabled)

3. **"Client ID not found" error**:
   - Verify the client ID and secret are correct in Kubernetes secrets
   - Check if the secrets are in the correct namespaces

### Debug Commands

```bash
# Check MinIO pods
kubectl get pods -n minio-tenant
kubectl logs -n minio-tenant deployment/minio-tenant

# Check Harbor pods
kubectl get pods -n harbor
kubectl logs -n harbor deployment/harbor-core

# Check secrets
kubectl get secrets -n minio-tenant | grep google
kubectl get secrets -n harbor | grep google
```

## Security Considerations

1. **Domain Restriction**: Use the `hd` parameter to restrict access to your Google Workspace domain
2. **Secret Management**: Store client secrets in Kubernetes secrets, not in configuration files
3. **HTTPS Only**: Ensure all redirect URIs use HTTPS
4. **Regular Rotation**: Rotate client secrets periodically
5. **Audit Logging**: Monitor authentication logs for suspicious activity

## Configuration Reference

### MinIO OIDC Environment Variables

```yaml
- name: MINIO_IDENTITY_OPENID_CONFIG_URL
  value: "https://accounts.google.com/.well-known/openid_configuration"
- name: MINIO_IDENTITY_OPENID_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: minio-google-workspace-oidc
      key: client-id
- name: MINIO_IDENTITY_OPENID_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: minio-google-workspace-oidc
      key: client-secret
- name: MINIO_IDENTITY_OPENID_CLAIM_NAME
  value: "email"
- name: MINIO_IDENTITY_OPENID_CLAIM_USERINFO
  value: "on"
- name: MINIO_IDENTITY_OPENID_REDIRECT_URI_DYNAMIC
  value: "on"
- name: MINIO_IDENTITY_OPENID_SCOPES
  value: "openid,profile,email"
- name: MINIO_IDENTITY_OPENID_CLAIM_PREFIX
  value: "google"
```

### Harbor OIDC Configuration

```yaml
oidc:
  name: "Google Workspace"
  endpoint: "https://accounts.google.com"
  clientIdSecretRef:
    name: harbor-google-workspace-oidc
    key: client-id
  clientSecretSecretRef:
    name: harbor-google-workspace-oidc
    key: client-secret
  scope: "openid,profile,email"
  verifyCert: true
  autoOnboard: true
  extraRedirectParms:
    scope: "openid,profile,email"
    hd: "theedgeworks.ai"
```