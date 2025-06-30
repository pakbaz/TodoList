# GitHub Repository Setup for Azure OIDC

This guide explains how to configure your GitHub repository to use OpenID Connect (OIDC) authentication with Azure.

## Overview

Microsoft Entra ID (formerly Azure AD) federated credentials have been set up for secure authentication between GitHub Actions and Azure without long-lived secrets. This uses OpenID Connect (OIDC) for enhanced security.

## GitHub Repository Configuration

### 1. Add Repository Secrets

Navigate to your GitHub repository: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add the following secrets:

| Secret Name | Value | Description |
|-------------|--------|-------------|
| `AZURE_CLIENT_ID` | `63b0cc38-b624-450d-8dab-4b9c10333d50` | Azure application (client) ID |
| `AZURE_TENANT_ID` | `16b3c013-d300-468d-ac64-7eda0820b6d3` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | `31123a85-42f7-4b2c-a74f-3c580102fb48` | Azure subscription ID |
| `POSTGRES_ADMIN_PASSWORD` | `your-secure-password` | PostgreSQL admin password (choose a strong password) |

### 2. Add Repository Variables (Optional)

Navigate to your GitHub repository: **Settings** → **Secrets and variables** → **Actions** → **Variables** tab → **New repository variable**

Add the following variables:

| Variable Name | Value | Description |
|---------------|--------|-------------|
| `AZURE_RESOURCE_GROUP` | `rg-todolist-dev` | Default resource group name |
| `AZURE_LOCATION` | `eastus` | Default Azure region |

## Azure Resources Created

The OIDC setup created the following Azure resources:

- **Application Registration**: `TodoList-GitHub-Actions-OIDC`
- **Service Principal**: Assigned Contributor role to subscription
- **Federated Credentials**: For secure GitHub authentication

### Federated Credentials Created

The following federated credentials were configured for different GitHub scenarios:

1. **main-branch**: `repo:pakbaz/TodoList:ref:refs/heads/main`
2. **pull-requests**: `repo:pakbaz/TodoList:pull_request`
3. **dev-environment**: `repo:pakbaz/TodoList:environment:dev`
4. **staging-environment**: `repo:pakbaz/TodoList:environment:staging`
5. **production-environment**: `repo:pakbaz/TodoList:environment:production`

## How OIDC Works

1. **GitHub Actions**: Requests an OIDC token from GitHub's token endpoint
2. **Azure**: Validates the token using the federated credentials
3. **Authentication**: Grants access based on the configured subject claims
4. **Authorization**: Uses the assigned Azure RBAC roles

## Security Benefits

✅ **No Long-lived Secrets**: No client secrets stored in GitHub
✅ **Short-lived Tokens**: OIDC tokens expire automatically
✅ **Granular Access**: Federated credentials limit access scope
✅ **Audit Trail**: Full logging of authentication events
✅ **Rotation-free**: No manual secret rotation required

## Workflow Usage

Your GitHub Actions workflow uses OIDC authentication like this:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - name: Azure Login
    uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

## Environment Protection

To enable environment protection:

1. Go to **Settings** → **Environments**
2. Create environments: `dev`, `staging`, `production`
3. Configure protection rules (optional):
   - Required reviewers
   - Wait timer
   - Deployment branches

## Troubleshooting

### Authentication Failures

If you see authentication errors:

1. **Verify Secrets**: Ensure all required secrets are configured correctly
2. **Check Permissions**: Verify the workflow has `id-token: write` permission
3. **Review Subject Claims**: Ensure the federated credential subjects match your repository
4. **Azure Role**: Confirm the service principal has appropriate Azure RBAC roles

### Common Issues

- **Wrong Branch**: Federated credentials are configured for `main` branch
- **Environment Mismatch**: Ensure environment names match federated credentials
- **Subscription Access**: Verify the service principal has access to the target subscription

## Next Steps

1. ✅ **Add the secrets** listed above to your GitHub repository
2. ✅ **Test the deployment** by pushing to the main branch or triggering manually
3. ✅ **Configure environments** for staging and production deployments
4. ✅ **Set up branch protection** rules for additional security

## Verification

To verify the setup is working:

1. Go to **Actions** tab in your GitHub repository
2. Trigger the "Deploy to Azure" workflow
3. Monitor the Azure Login step for successful authentication
4. Check Azure portal for deployed resources

The deployment pipeline is now secure and ready for production use! 🚀
