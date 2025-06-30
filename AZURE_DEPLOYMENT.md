# Azure Deployment Guide

This guide walks you through deploying the TodoList application to Azure using Azure Container Apps, Azure PostgreSQL, and GitHub Actions CI/CD with Bicep Infrastructure as Code.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│                 │    │                  │    │                 │
│   GitHub Repo   │───▶│  GitHub Actions  │───▶│  Azure Cloud    │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                         │
                                ▼                         ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │                  │    │                 │
                       │   Bicep Deploy   │    │ Container Apps  │
                       │   & Docker Build │    │ + PostgreSQL   │
                       │                  │    │                 │
                       └──────────────────┘    └─────────────────┘
```

### Azure Resources

- **Azure Container Apps**: Serverless container hosting
- **Azure PostgreSQL Flexible Server**: Managed database
- **Azure Container Registry**: Private container images
- **Azure Key Vault**: Secure secrets management
- **Azure Log Analytics**: Monitoring and logging
- **Application Insights**: Application performance monitoring
- **Managed Identity**: Secure service-to-service authentication

## Prerequisites

1. **Azure Account**: Active Azure subscription
2. **GitHub Repository**: Your TodoList code repository
3. **Local Tools** (optional for local testing):
   - Azure CLI (`az`)
   - Docker Desktop
   - Git

### Installation Commands

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Docker Desktop
# Download from https://www.docker.com/products/docker-desktop/
```

## Setup Instructions

### Step 1: Clone and Prepare Repository

```bash
git clone <your-repo-url>
cd TodoList
```

### Step 2: Configure Azure Authentication (OIDC)

#### Option A: Using the Setup Script (Recommended)

**Linux/macOS:**
```bash
chmod +x scripts/setup-azure-oidc.sh
./scripts/setup-azure-oidc.sh
```

**Windows (PowerShell):**
```powershell
.\scripts\setup-azure-oidc.ps1 -GitHubOrg "your-org" -GitHubRepo "your-repo"
```

#### Option B: Manual Setup

1. **Login to Azure:**
   ```bash
   az login
   ```

2. **Get your subscription and tenant info:**
   ```bash
   az account show
   ```

3. **Create Azure AD Application:**
   ```bash
   APP_NAME="GithubOIDC-TodoList-dev"
   APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId --output tsv)
   ```

4. **Create Service Principal:**
   ```bash
   az ad sp create --id $APP_ID
   ```

5. **Create Resource Group:**
   ```bash
   az group create --name "rg-dev" --location "eastus"
   ```

6. **Assign Contributor Role:**
   ```bash
   az role assignment create \
     --assignee $APP_ID \
     --role "Contributor" \
     --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-dev"
   ```

7. **Create Federated Credentials:**
   ```bash
   # Main branch
   az ad app federated-credential create --id $APP_ID --parameters '{
     "name": "github-main",
     "issuer": "https://token.actions.githubusercontent.com",
     "subject": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main",
     "audiences": ["api://AzureADTokenExchange"]
   }'
   
   # Pull requests
   az ad app federated-credential create --id $APP_ID --parameters '{
     "name": "github-pr", 
     "issuer": "https://token.actions.githubusercontent.com",
     "subject": "repo:YOUR_ORG/YOUR_REPO:pull_request",
     "audiences": ["api://AzureADTokenExchange"]
   }'
   ```

### Step 3: Configure GitHub Repository

1. **Go to your GitHub repository settings**
2. **Navigate to "Secrets and variables" > "Actions" > "Variables"**
3. **Add the following repository variables:**

   | Variable Name | Value | Description |
   |---------------|-------|-------------|
   | `AZURE_CLIENT_ID` | `<APP_ID from step 2>` | Azure AD Application ID |
   | `AZURE_TENANT_ID` | `<Your tenant ID>` | Azure AD Tenant ID |
   | `AZURE_SUBSCRIPTION_ID` | `<Your subscription ID>` | Azure Subscription ID |
   | `AZURE_LOCATION` | `eastus` | Azure region for deployment |

4. **Create Environment (Optional but Recommended):**
   - Go to "Settings" > "Environments"
   - Create environment: `dev`
   - Add required reviewers if desired
   - Add environment protection rules

### Step 4: Deploy to Azure

#### Automatic Deployment

Push your code to the `main` branch:

```bash
git add .
git commit -m "Deploy TodoList to Azure"
git push origin main
```

The GitHub Actions workflow will automatically:
1. Build and test the application
2. Provision Azure infrastructure
3. Build and push Docker image to ACR
4. Deploy the application to Container Apps
5. Run deployment verification tests

#### Manual Deployment

You can also trigger deployment manually:

1. Go to "Actions" tab in your GitHub repository
2. Select "Deploy to Azure" workflow
3. Click "Run workflow"
4. Choose environment and run

#### Local Deployment (Development)

For local testing of infrastructure (optional):

```bash
# Login to Azure
az login

# Deploy infrastructure to Azure
az deployment group create \
  --resource-group rg-todolist-dev \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json

# Build and push container manually (if needed)
az acr build --registry <acr-name> --image todolist-app:latest .
```

## Monitoring and Management

### Application URLs

After deployment, you'll have access to:

- **Web Application**: `https://<your-app>.azurecontainerapps.io`
- **Health Check**: `https://<your-app>.azurecontainerapps.io/health`
- **API Endpoints**: `https://<your-app>.azurecontainerapps.io/mcp/todos`

### Azure Portal Monitoring

1. **Container Apps**: Monitor application logs and metrics
2. **PostgreSQL**: Database performance and connectivity
3. **Key Vault**: Secret access logs
4. **Application Insights**: Application performance and errors

### Log Analysis

```bash
# View application logs
docker logs <container_name>

# Or using Azure CLI
az containerapp logs show --name <app-name> --resource-group <rg-name>
```

## Environment Configuration

### Development Environment

- **Environment Name**: `dev`
- **Resource Group**: `rg-dev`
- **Auto-scaling**: 1-10 replicas
- **Database**: Burstable tier (cost-optimized)

### Production Environment

To deploy to production:

1. **Update the setup script with prod environment:**
   ```bash
   ./scripts/setup-azure-oidc.sh # Use "prod" when prompted
   ```

2. **Create production environment in GitHub**
3. **Add production-specific variables**
4. **Trigger deployment:**
   ```bash
   gh workflow run "Deploy to Azure" --field environment=prod
   ```

## Cost Optimization

### Development
- Container Apps: ~$5-10/month (with minimal usage)
- PostgreSQL: ~$15-30/month (Burstable B1ms)
- Storage & networking: ~$5/month
- **Total**: ~$25-45/month

### Production
- Container Apps: ~$50-100/month (with auto-scaling)
- PostgreSQL: ~$100-200/month (General Purpose)
- Storage & networking: ~$20/month
- **Total**: ~$170-320/month

### Cost Reduction Tips

1. **Use Azure Cost Management** to monitor spending
2. **Set up budget alerts** for cost control
3. **Scale down dev environments** when not in use
4. **Use Azure Advisor** recommendations
5. **Consider reserved instances** for production

## Troubleshooting

### Common Issues

#### 1. Authentication Errors
```
Error: Failed to exchange token
```
**Solution**: Verify federated credentials are correctly configured for your repository.

#### 2. Resource Group Already Exists
```
Error: The resource group 'rg-dev' already exists
```
**Solution**: Use a different environment name or delete the existing resource group.

#### 3. Database Connection Issues
```
Error: Connection to database failed
```
**Solutions**:
- Check PostgreSQL firewall rules
- Verify connection string in Key Vault
- Ensure managed identity has Key Vault access

#### 4. Container Image Pull Errors
```
Error: Failed to pull image from registry
```
**Solutions**:
- Verify ACR permissions for managed identity
- Check if image was successfully pushed
- Review container registry logs

### Debug Commands

```bash
# Check Azure resources
az resource list --resource-group rg-todolist-dev --output table

# Test container app
az containerapp show --name <app-name> --resource-group rg-todolist-dev

# Check PostgreSQL connectivity
az postgres flexible-server show --name <server-name> --resource-group rg-todolist-dev

# View Key Vault secrets
az keyvault secret list --vault-name <vault-name>

# Container logs
az containerapp logs show --name <app-name> --resource-group rg-todolist-dev --follow

# Check deployment status
az deployment group show --resource-group rg-todolist-dev --name <deployment-name>
```

### Getting Help

1. **Check GitHub Actions logs** for deployment issues
2. **Review Azure Monitor** for runtime issues  
3. **Check Azure Service Health** for platform issues
4. **Contact Azure Support** for Azure-specific problems

## Security Best Practices

1. **Use Managed Identities** instead of connection strings where possible
2. **Store all secrets in Key Vault** 
3. **Enable HTTPS only** for all endpoints
4. **Regularly rotate secrets** and certificates
5. **Monitor access logs** in Key Vault and Container Apps
6. **Use least privilege** for role assignments
7. **Enable Azure Defender** for additional security monitoring

## Updating the Application

### Code Changes

1. Create a feature branch
2. Make your changes
3. Create a pull request (triggers build/test)
4. Merge to main (triggers deployment)

### Infrastructure Changes

1. Modify Bicep templates in `infra/`
2. Test changes with `az deployment group validate`
3. Deploy via GitHub Actions push to main branch

### Database Schema Changes

For production databases, consider:
1. **Backup before changes**
2. **Use migration scripts**
3. **Test in staging first**
4. **Plan for rollback scenarios**

## Next Steps

1. **Set up monitoring alerts** in Azure Monitor
2. **Configure backup policies** for PostgreSQL
3. **Implement blue-green deployments** for zero-downtime updates
4. **Add integration tests** to the CI/CD pipeline
5. **Set up disaster recovery** for production environments

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `az deployment group create --template-file infra/main.bicep` | Deploy infrastructure |
| `az acr build --registry <acr> --image <image>:<tag> .` | Build and push container |
| `az containerapp logs show --name <app> --resource-group <rg>` | View application logs |
| `az group delete --name <rg> --yes` | Delete all resources |
| `az containerapp show --name <app> --resource-group <rg>` | Check app status |

For more detailed information, refer to the [Azure Container Apps documentation](https://learn.microsoft.com/en-us/azure/container-apps/) and [Bicep documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/).
