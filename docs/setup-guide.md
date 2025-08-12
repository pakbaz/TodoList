# Azure IaC & CI/CD Setup Guide

## 🎯 Overview

This guide walks you through setting up complete Azure Infrastructure as Code (IaC) and CI/CD for the TodoList application using:

- **Azure Container Apps** for serverless container hosting
- **PostgreSQL Flexible Server** for managed database
- **Azure Container Registry** for private container images
- **Azure Key Vault** for secrets management
- **GitHub Actions** with OIDC for secure CI/CD

## 🚀 Quick Start

### Prerequisites

1. **Azure Subscription** with Contributor access
2. **GitHub Repository** with Actions enabled
3. **Azure CLI** installed locally
4. **Owner permissions** for creating service principals

### Step 1: Azure Service Principal Setup

Create a service principal for GitHub Actions OIDC authentication:

```bash
# Set your variables
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP_DEV="todolist-rg-dev"
RESOURCE_GROUP_PROD="todolist-rg-prod"
GITHUB_REPO="your-username/TodoList"

# Login to Azure
az login

# Set subscription
az account set --subscription $SUBSCRIPTION_ID

# Create resource groups
az group create --name $RESOURCE_GROUP_DEV --location "East US"
az group create --name $RESOURCE_GROUP_PROD --location "East US"

# Create service principal
APP_ID=$(az ad app create --display-name "TodoList-GitHub-Actions" --query appId -o tsv)

# Create service principal
SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv)

# Assign Contributor role to both resource groups
az role assignment create --assignee $APP_ID --role Contributor --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_DEV"
az role assignment create --assignee $APP_ID --role Contributor --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_PROD"

# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "App ID: $APP_ID"
echo "Tenant ID: $TENANT_ID"
echo "Subscription ID: $SUBSCRIPTION_ID"
```

### Step 2: Configure OIDC Federated Credentials

```bash
# Create federated credential for main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "TodoList-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_REPO"':ref:refs/heads/main",
    "description": "GitHub Actions main branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "TodoList-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_REPO"':pull_request",
    "description": "GitHub Actions pull requests",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### Step 3: GitHub Repository Configuration

#### Repository Secrets

Add these secrets in GitHub: **Settings > Secrets and variables > Actions > Secrets**

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AZURE_CLIENT_ID` | `$APP_ID` | Service principal client ID |
| `AZURE_TENANT_ID` | `$TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | `$SUBSCRIPTION_ID` | Azure subscription ID |
| `POSTGRESQL_ADMIN_PASSWORD` | `TodoList@123456` | Database password for dev |
| `POSTGRESQL_ADMIN_PASSWORD_PROD` | `SecurePassword123!` | Database password for prod |

#### Repository Variables

Add these variables in GitHub: **Settings > Secrets and variables > Actions > Variables**

| Variable Name | Value | Description |
|---------------|-------|-------------|
| `ACR_NAME` | `todolistacrdev` | Dev container registry name |
| `ACR_NAME_PROD` | `todolistacrprod` | Prod container registry name |
| `AZURE_LOCATION` | `East US` | Azure region |
| `POSTGRESQL_ADMIN_LOGIN` | `todolistadmin` | Database admin username |

#### Environment Protection

1. Go to **Settings > Environments**
2. Create environments: `development`, `staging`, `production`
3. For `production` environment:
   - ✅ Required reviewers (add yourself)
   - ✅ Wait timer: 5 minutes
   - ⚠️ Deployment branches: Only protected branches

### Step 4: First Deployment

#### Option A: Manual Deployment (Recommended)

```bash
# Deploy development environment
az deployment group create \
  --resource-group $RESOURCE_GROUP_DEV \
  --template-file infra/main.bicep \
  --parameters @infra/parameters-dev.json
```

#### Option B: GitHub Actions Deployment

1. Push code to trigger CI pipeline:
   ```bash
   git push origin main
   ```

2. Monitor the deployment:
   - Go to **Actions** tab in GitHub
   - Watch the CI/CD pipeline execution

### Step 5: Verify Deployment

Once deployment completes, verify the application:

```bash
# Get the application URL
az containerapp show \
  --name todolist-app-dev \
  --resource-group $RESOURCE_GROUP_DEV \
  --query "properties.configuration.ingress.fqdn" -o tsv
```

Visit the application:
- **Web UI**: `https://{fqdn}`
- **Health Check**: `https://{fqdn}/health`
- **API**: `https://{fqdn}/mcp/todos`

## 📋 Resource Checklist

After successful deployment, you should see these Azure resources:

### Development Environment (`todolist-rg-dev`)
- ✅ Container Apps Environment (`todolist-env-dev`)
- ✅ Container App (`todolist-app-dev`)
- ✅ Container Registry (`todolistacrdev`)
- ✅ PostgreSQL Server (`todolist-db-dev`)
- ✅ Key Vault (`todolist-kv-dev-xxxxx`)
- ✅ Log Analytics Workspace (`todolist-logs-dev`)

### Production Environment (`todolist-rg-prod`)
- ⏳ Deploy manually or via GitHub Actions

## 🔧 Configuration Management

### Environment-Specific Settings

| Setting | Development | Production |
|---------|-------------|------------|
| Min Replicas | 1 | 2 |
| Max Replicas | 3 | 10 |
| CPU | 250m | 500m |
| Memory | 512Mi | 1Gi |
| Database SKU | Standard_B1ms | Standard_D2s_v3 |

### Scaling Configuration

The application automatically scales based on:
- **HTTP Requests**: > 100 concurrent requests
- **CPU Usage**: > 70% utilization
- **Custom Metrics**: Application-specific metrics

## 🔐 Security Features

### Authentication & Authorization
- ✅ **OIDC**: Passwordless GitHub to Azure authentication
- ✅ **Managed Identity**: Service-to-service authentication
- ✅ **RBAC**: Role-based access control
- ✅ **Key Vault**: Centralized secrets management

### Network Security
- ✅ **HTTPS Only**: Enforced SSL/TLS for all traffic
- ✅ **Private ACR**: Container registry with managed identity access
- ✅ **Database Firewall**: Restricted PostgreSQL access
- 🔄 **VNet Integration**: Optional private networking (Phase 2)

### Monitoring & Compliance
- ✅ **Centralized Logging**: Log Analytics workspace
- ✅ **Health Monitoring**: Application Insights integration
- ✅ **Audit Logging**: Azure Activity Log
- ✅ **Resource Tagging**: Consistent tagging strategy

## 📊 Monitoring & Operations

### Application Health

Monitor application health through:

1. **Azure Portal**: Container Apps metrics and logs
2. **GitHub Actions**: Deployment status and health checks
3. **Application Endpoints**:
   - Health: `GET /health`
   - Metrics: Built-in Container Apps metrics

### Key Metrics to Monitor

| Metric | Threshold | Action |
|--------|-----------|--------|
| CPU Usage | > 80% | Scale up |
| Memory Usage | > 85% | Scale up |
| Response Time | > 2s | Investigate |
| Error Rate | > 5% | Alert |
| Database Connections | > 80% | Scale database |

### Log Analysis

Common log queries for troubleshooting:

```kusto
// Application errors
ContainerAppConsoleLogs_CL
| where Log_s contains "ERROR"
| order by TimeGenerated desc

// Database connection issues
ContainerAppConsoleLogs_CL
| where Log_s contains "PostgreSQL" or Log_s contains "Database"
| order by TimeGenerated desc

// Performance issues
ContainerAppConsoleLogs_CL
| where Log_s contains "timeout" or Log_s contains "slow"
| order by TimeGenerated desc
```

## 🚀 Deployment Workflows

### Development Workflow

1. **Feature Development**: Work on feature branch
2. **Pull Request**: Create PR with automatic CI
3. **Code Review**: Team review and approval
4. **Merge to Main**: Automatic deployment to dev
5. **Testing**: Manual testing in dev environment

### Production Workflow

1. **Manual Trigger**: Use GitHub Actions workflow dispatch
2. **Environment Selection**: Choose staging or production
3. **Approval Process**: Required for production deployments
4. **Health Verification**: Automated health checks
5. **Rollback**: Instant rollback capability via Container Apps revisions

## 🔄 Rollback Procedures

### Application Rollback

```bash
# List revisions
az containerapp revision list \
  --name todolist-app-prod \
  --resource-group $RESOURCE_GROUP_PROD

# Activate previous revision
az containerapp revision activate \
  --name todolist-app-prod-<previous-revision> \
  --resource-group $RESOURCE_GROUP_PROD
```

### Infrastructure Rollback

Infrastructure rollback is handled via:
1. **Bicep Templates**: Version-controlled infrastructure
2. **Parameter Files**: Environment-specific configurations
3. **Git History**: Rollback to previous commit and redeploy

## 🛠️ Troubleshooting

### Common Issues

1. **Container Startup Failures**
   ```bash
   # Check container logs
   az containerapp logs show \
     --name todolist-app-dev \
     --resource-group $RESOURCE_GROUP_DEV
   ```

2. **Database Connection Issues**
   ```bash
   # Verify database status
   az postgres flexible-server show \
     --name todolist-db-dev \
     --resource-group $RESOURCE_GROUP_DEV
   ```

3. **GitHub Actions Failures**
   - Check repository secrets and variables
   - Verify Azure permissions
   - Review workflow logs in GitHub Actions tab

### Support Resources

- 📖 **Documentation**: `/docs/devops.md`
- 🔍 **Best Practices**: `/docs/best-practices.md`
- 📋 **Implementation Plan**: `/docs/plan.md`
- 💬 **Azure Support**: Azure portal support requests
- 🐙 **GitHub Issues**: Repository issue tracker

## 🎉 Next Steps

After successful deployment:

1. **Configure Custom Domain** (Optional)
2. **Set up Application Insights** for detailed monitoring
3. **Implement VNet Integration** for enhanced security
4. **Add Application Gateway** with WAF
5. **Configure Backup Strategies**
6. **Set up Cross-Region Deployment**

---

**✅ You're all set!** Your TodoList application is now running on Azure with enterprise-grade CI/CD and infrastructure automation.
