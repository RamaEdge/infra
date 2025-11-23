# Setting up Google OAuth for MinIO

This guide explains how to configure Google OAuth authentication for MinIO using Google Cloud Console (via Google Workspace).

## Prerequisites

- **Google Workspace Admin** access.
- Access to [Google Cloud Console](https://console.cloud.google.com/).
- MinIO Console URL: `https://minio-console.theedgeworks.ai`

## Step 1: Create OAuth Credentials

1.  Log in to [Google Cloud Console](https://console.cloud.google.com/).
2.  Select your project (e.g., "Internal Tools").
3.  Navigate to **APIs & Services > Credentials**.
4.  Click **Create Credentials** and select **OAuth client ID**.
5.  Select **Web application**.
6.  Name it "MinIO".
7.  **Authorized JavaScript origins**:
    -   `https://minio-console.theedgeworks.ai`
8.  **Authorized redirect URIs**:
    -   `https://minio-console.theedgeworks.ai/oauth_callback`
9.  Click **Create**.
10. Copy the **Client ID** and **Client Secret**.

## Step 2: Create Kubernetes Secret

Create a secret in the `minio-tenant` namespace with your credentials.

```bash
kubectl create secret generic minio-google-workspace-oidc \
  --namespace minio-tenant \
  --from-literal=client-id='<YOUR_CLIENT_ID>' \
  --from-literal=client-secret='<YOUR_CLIENT_SECRET>'
```

## Step 3: Verify Configuration

The `tenant.yaml` is configured to use these credentials. MinIO will automatically enable the "Login with OpenID" button on the console.

**Note on Policies:**
By default, authenticated users might not have any permissions. You may need to set up MinIO policies to grant access to users logging in via OIDC.
You can map the OIDC users to policies using the `mc` CLI or the Console (once logged in as admin).
