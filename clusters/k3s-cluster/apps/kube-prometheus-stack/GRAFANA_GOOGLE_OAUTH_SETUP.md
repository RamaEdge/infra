# Setting up Google OAuth for Grafana

This guide explains how to configure Google OAuth authentication for Grafana using Google Cloud Console.

## Prerequisites

- **Google Workspace Admin** access (or ability to create projects in Google Cloud Console)
- **Note**: You do **NOT** need a paid Google Cloud Platform (GCP) subscription. You only need access to the [Google Cloud Console](https://console.cloud.google.com/) to generate API credentials, which is included with Google Workspace.
- A domain for your Grafana instance (e.g., `monitor.theedgeworks.ai`)

## Step 1: Access Google Cloud Console

Even if you only use Google Workspace, you must use the Google Cloud Console to generate OAuth credentials.

1.  Log in to [Google Cloud Console](https://console.cloud.google.com/) using your Google Workspace admin account.
2.  If you haven't used it before, you may need to agree to the terms of service.
3.  Create a new project (e.g., "Internal Tools" or "Grafana Auth"). This acts as a container for your credentials.

## Step 2: Configure OAuth Consent Screen

1.  Navigate to **APIs & Services > OAuth consent screen**.
2.  Select **Internal** (if you only want users from your Google Workspace organization) or **External**.
3.  Click **Create**.
4.  Fill in the **App Information**:
    -   **App name**: Grafana
    -   **User support email**: Your email
    -   **Developer contact information**: Your email
5.  Click **Save and Continue**.
6.  (Optional) Add Scopes: `openid`, `auth/userinfo.email`, `auth/userinfo.profile`.
7.  Click **Save and Continue**.

## Step 3: Create OAuth Credentials

1.  Navigate to **APIs & Services > Credentials**.
2.  Click **Create Credentials** and select **OAuth client ID**.
3.  Select **Web application** as the Application type.
4.  Name it "Grafana".
5.  **Authorized JavaScript origins**:
    -   `https://monitor.theedgeworks.ai`
6.  **Authorized redirect URIs**:
    -   `https://monitor.theedgeworks.ai/login/google`
7.  Click **Create**.
8.  **Important**: Copy the **Client ID** and **Client Secret**. You will need these for the Kubernetes secret.

## Step 4: Create Kubernetes Secret

Create a secret in the `monitoring` namespace with your credentials.

```bash
kubectl create secret generic grafana-google-oidc \
  --namespace monitoring \
  --from-literal=GF_AUTH_GOOGLE_CLIENT_ID='<YOUR_CLIENT_ID>' \
  --from-literal=GF_AUTH_GOOGLE_CLIENT_SECRET='<YOUR_CLIENT_SECRET>'
```

## Step 5: Verify Configuration

The `helmrelease.yaml` has been configured to:
1.  Load environment variables from the `grafana-google-oidc` secret.
2.  Configure `grafana.ini` to enable Google Auth and allow sign-ups from your domain.

**Note**: Ensure you update the `allowed_domains` in `helmrelease.yaml` if you want to restrict access to a specific domain (e.g., `theedgeworks.ai`).
