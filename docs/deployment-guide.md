# Deployment Guide

This guide provides step-by-step instructions for deploying the TodoList application to Azure using the automated CI/CD pipeline.

## Prerequisites

1. **Azure Subscription**: Active Azure subscription with appropriate permissions
2. **GitHub Repository**: TodoList code hosted on GitHub
3. **Azure CLI**: Installed and configured locally
4. **Docker**: Installed for local container testing (optional)

## Step 1: Initial Setup

### 1.1 Clone Repository
```bash
git clone https://github.com/YOUR_USERNAME/TodoList.git
cd TodoList
```

### 1.2 Azure CLI Login
```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

## Step 2: Configure Azure OIDC Authentication

Follow the detailed instructions in `docs/azure-devops-setup.md` to:

1. Create Azure AD App Registration
2. Configure OIDC federated credentials
3. Assign required Azure permissions
4. Set up GitHub repository secrets

## Step 3: Environment Configuration

### 3.1 GitHub Repository Secrets

Navigate to GitHub repository Settings > Secrets and variables > Actions and add:

**Repository Secrets:**
- `AZURE_CLIENT_ID`: Your Azure AD application client ID
- `AZURE_TENANT_ID`: Your Azure tenant ID  
- `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID
- `POSTGRES_ADMIN_PASSWORD`: Strong password for PostgreSQL (e.g., `SecurePass123!@#`)

### 3.2 Environment Protection Rules

**Development Environment:**
- No protection rules (automatic deployment on main branch)

**Staging Environment:**
- Go to Settings > Environments > New environment: `staging`
- Add protection rule: Required reviewers (team members)

**Production Environment:**
- Go to Settings > Environments > New environment: `prod`
- Add protection rule: Required reviewers (administrators)
- Add wait timer: 5 minutes

## Step 4: Deploy Infrastructure and Application

### 4.1 Automatic Deployment (Recommended)

**Deploy to Development:**
```bash
# Push to main branch triggers automatic dev deployment
git checkout main
git push origin main
```

**Deploy to Staging:**
```bash
# Use GitHub Actions workflow dispatch
# Go to Actions tab > Deploy TodoList Application > Run workflow
# Select 'staging' environment
```

**Deploy to Production:**
```bash
# Use GitHub Actions workflow dispatch
# Go to Actions tab > Deploy TodoList Application > Run workflow  
# Select 'prod' environment
# Approve the deployment after review
```

### 4.2 Manual Infrastructure Deployment (Alternative)

If you need to deploy infrastructure manually:

```bash
# Deploy to development
az deployment sub create \
  --location "East US 2" \
  --template-file infra/main.bicep \
  --parameters infra/parameters/dev.bicepparam \
  --name "infrastructure-dev-manual"

# Deploy application
az deployment group create \
  --resource-group "rg-todolist-dev" \
  --template-file infra/deploy-app.bicep \
  --parameters environmentName=dev applicationName=todolist \
  --name "app-dev-manual"
```

## Step 5: Verify Deployment

### 5.1 Check Infrastructure

```bash
# List resources in development environment
az resource list --resource-group "rg-todolist-dev" --output table

# Check Container App status
az containerapp show \
  --name "todolist-dev" \
  --resource-group "rg-todolist-dev" \
  --query "properties.provisioningState"
```

### 5.2 Access Application

```bash
# Get application URL
az containerapp show \
  --name "todolist-dev" \
  --resource-group "rg-todolist-dev" \
  --query "properties.configuration.ingress.fqdn" \
  --output tsv
```

### 5.3 Test Application Functionality

1. **Home Page**: Navigate to the application URL
2. **Todo Page**: Access `/todo` endpoint
3. **Database**: Add a few todo items to test database connectivity
4. **Health Check**: Verify application logs in Azure portal

## Step 6: Monitoring and Troubleshooting

### 6.1 View Application Logs

```bash
# Stream container app logs
az containerapp logs show \
  --name "todolist-dev" \
  --resource-group "rg-todolist-dev" \
  --follow

# View Application Insights
# Navigate to Azure portal > Application Insights > todolist-dev-ai
```

### 6.2 Common Issues

**Container App Not Starting:**
- Check container logs for startup errors
- Verify environment variables are set correctly
- Ensure container image was pushed successfully

**Database Connection Issues:**
- Verify PostgreSQL server is running
- Check managed identity permissions
- Review connection string configuration

**GitHub Actions Failures:**
- Verify OIDC authentication configuration
- Check Azure permissions for service principal
- Review workflow logs for specific error messages

### 6.3 Rollback Procedure

```bash
# Get previous revision
az containerapp revision list \
  --name "todolist-dev" \
  --resource-group "rg-todolist-dev" \
  --output table

# Activate previous revision
az containerapp revision activate \
  --revision "todolist-dev--previous-revision-name" \
  --resource-group "rg-todolist-dev"
```

## Step 7: Cleanup (Optional)

To remove all resources:

```bash
# Delete resource groups (this removes all resources)
az group delete --name "rg-todolist-dev" --yes --no-wait
az group delete --name "rg-todolist-staging" --yes --no-wait  
az group delete --name "rg-todolist-prod" --yes --no-wait
```

## Additional Resources

- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure OIDC with GitHub Actions](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure)
