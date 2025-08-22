# Azure DevOps Environment Setup

This document provides the setup instructions for Azure DevOps environments and OIDC authentication.

## 1. Azure Service Principal and OIDC Setup

### Create Azure AD App Registration

```bash
# Create the app registration
az ad app create --display-name "TodoList-GitHub-Actions" --sign-in-audience AzureADMyOrg

# Get the Application (Client) ID
APP_ID=$(az ad app list --display-name "TodoList-GitHub-Actions" --query "[0].appId" -o tsv)
echo "Application ID: $APP_ID"

# Create a service principal
az ad sp create --id $APP_ID

# Get the Object ID of the service principal
OBJECT_ID=$(az ad sp list --display-name "TodoList-GitHub-Actions" --query "[0].id" -o tsv)
echo "Service Principal Object ID: $OBJECT_ID"
```

### Configure OIDC Trust

```bash
# Configure federated credentials for GitHub Actions
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "GitHub-Actions-Main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_USERNAME/TodoList:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Configure federated credentials for pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "GitHub-Actions-PR",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_USERNAME/TodoList:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### Assign Azure Permissions

```bash
# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)

# Assign Contributor role at subscription level
az role assignment create \
  --role "Contributor" \
  --assignee $OBJECT_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Assign User Access Administrator role (needed for role assignments)
az role assignment create \
  --role "User Access Administrator" \
  --assignee $OBJECT_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

## 2. GitHub Repository Secrets

Add the following secrets to your GitHub repository (Settings > Secrets and variables > Actions):

### Repository Secrets
- `AZURE_CLIENT_ID`: The Application (Client) ID from Azure AD
- `AZURE_TENANT_ID`: Your Azure tenant ID
- `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID
- `POSTGRES_ADMIN_PASSWORD`: Strong password for PostgreSQL admin user

### Environment Secrets (for each environment: dev, staging, prod)
- Add environment-specific configurations if needed

## 3. GitHub Environment Protection Rules

### Development Environment
- No protection rules (automatic deployment)

### Staging Environment
- Require review from maintainers
- Wait timer: 0 minutes

### Production Environment
- Require review from administrators
- Wait timer: 5 minutes
- Environment secrets for production-specific configurations

## 4. Commands to Get Required Values

```bash
# Get Tenant ID
az account show --query "tenantId" -o tsv

# Get Subscription ID
az account show --query "id" -o tsv

# Get Client ID (after app registration)
az ad app list --display-name "TodoList-GitHub-Actions" --query "[0].appId" -o tsv
```

## 5. Testing the Setup

After configuring everything:

1. Push to a feature branch and create a PR to test the workflow
2. Merge to main to test full deployment
3. Use manual workflow dispatch to test specific environments

## 6. Troubleshooting

### Common Issues
- **OIDC authentication fails**: Verify federated credentials are configured correctly
- **Permission denied**: Ensure service principal has Contributor and User Access Administrator roles
- **Resource already exists**: Infrastructure is idempotent, but check for naming conflicts
- **Container app deployment fails**: Verify container registry permissions and image exists

### Debugging Commands
```bash
# Check role assignments
az role assignment list --assignee $OBJECT_ID

# Verify federated credentials
az ad app federated-credential list --id $APP_ID

# Test Azure CLI login with OIDC
az login --service-principal -u $APP_ID --tenant $TENANT_ID --federated-token $GITHUB_TOKEN
```
