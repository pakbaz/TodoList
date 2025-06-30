# TodoList Azure Deployment - Quick Start Guide

This is a simplified guide for deploying the TodoList application to Azure using GitHub Actions and Bicep Infrastructure as Code.

## Prerequisites

- Azure subscription
- GitHub repository with this code
- Azure CLI (optional, for local testing)

## Quick Deployment (Recommended)

### 1. Set up Azure OIDC Authentication

Run the setup script to configure OIDC between GitHub and Azure:

**Windows:**
```powershell
.\scripts\setup-azure-oidc.ps1 -GitHubOrg "your-github-org" -GitHubRepo "your-repo-name"
```

**Linux/macOS:**
```bash
chmod +x scripts/setup-azure-oidc.sh
./scripts/setup-azure-oidc.sh
```

### 2. Configure GitHub Repository

The setup script will output variables to add to your GitHub repository:

1. Go to your GitHub repository → Settings → Secrets and variables → Actions → Variables
2. Add these repository variables:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID` 
   - `AZURE_SUBSCRIPTION_ID`
   - `AZURE_LOCATION` (e.g., "eastus")

3. Go to Secrets tab and add:
   - `POSTGRES_ADMIN_PASSWORD` (secure password for PostgreSQL)

### 3. Deploy

Simply push to the main branch:

```bash
git add .
git commit -m "Deploy to Azure"
git push origin main
```

Or trigger manually from GitHub Actions → Deploy to Azure → Run workflow.

## What Gets Deployed

The deployment creates these Azure resources:

- **Container Apps** - Hosts your application
- **PostgreSQL Database** - Managed database service  
- **Container Registry** - Stores your container images
- **Key Vault** - Securely stores database passwords
- **Application Insights** - Monitors performance
- **Log Analytics** - Centralized logging

## Access Your Application

After deployment completes, you'll find the application URL in the GitHub Actions logs or Azure Portal.

Your application will be available at:
- **Web UI**: `https://<your-app>.azurecontainerapps.io`
- **Health Check**: `https://<your-app>.azurecontainerapps.io/health`
- **API**: `https://<your-app>.azurecontainerapps.io/mcp/todos`

## Local Development

For local development, use Docker Compose:

```bash
docker-compose up -d
```

Access locally at: http://localhost:8080

## Manual Deployment (Advanced)

If you prefer to deploy manually:

```bash
# Login to Azure
az login

# Create resource group
az group create --name rg-todolist-dev --location eastus

# Deploy infrastructure
az deployment group create \
  --resource-group rg-todolist-dev \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json

# Build and push container
az acr build --registry <acr-name> --image todolist-app:latest .
```

## Troubleshooting

### Common Issues

1. **Authentication Error**: Verify OIDC setup and GitHub variables
2. **Build Failures**: Check GitHub Actions logs for details
3. **Application Not Starting**: Check Application Insights for errors

### Getting Help

- Check the full [Azure Deployment Guide](AZURE_DEPLOYMENT.md) for detailed instructions
- Review GitHub Actions logs for deployment issues
- Use Azure Portal to monitor resources

## Cost Estimation

- **Development**: ~$25-45/month
- **Production**: ~$170-320/month

The application uses Azure's serverless Container Apps, so you only pay for what you use.

---

That's it! Your TodoList application should now be running on Azure with a full CI/CD pipeline.
