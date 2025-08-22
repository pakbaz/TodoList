# TodoList Infrastructure as Code

This directory contains the Infrastructure as Code (IaC) setup for the TodoList application using Azure Bicep templates and GitHub Actions CI/CD.

## 🏗️ Architecture Overview

The infrastructure deploys a modern cloud-native application stack on Azure:

- **Azure Container Apps**: Serverless container hosting with auto-scaling
- **PostgreSQL Flexible Server**: Managed database with private networking
- **Azure Container Registry**: Private container image storage
- **Azure Key Vault**: Secure secrets management
- **Application Insights**: Application monitoring and analytics
- **Virtual Network**: Secure private networking with subnet isolation

## 📁 Directory Structure

```
infra/
├── main.bicep                     # Main orchestration template
├── modules/                       # Reusable Bicep modules
│   ├── network.bicep             # VNet, subnets, NSGs, DNS zones
│   ├── keyvault.bicep            # Key Vault with private endpoint
│   ├── monitoring.bicep          # Log Analytics & Application Insights
│   ├── container-registry.bicep  # Azure Container Registry
│   ├── postgresql.bicep          # PostgreSQL Flexible Server
│   ├── container-apps.bicep      # Container Apps Environment & App
│   └── secrets.bicep             # Secret management & RBAC
├── parameters/                    # Environment-specific parameters
│   ├── dev.parameters.json       # Development environment
│   ├── staging.parameters.json   # Staging environment
│   └── prod.parameters.json      # Production environment
└── workbooks/                     # Azure Workbook dashboards
    └── todolist-dashboard.json   # Application monitoring dashboard
```

## 🚀 Quick Start

### Prerequisites

1. **Azure Subscription** with Contributor access
2. **Azure CLI** (v2.50.0+) or **Azure PowerShell**
3. **GitHub repository** with OIDC federation configured
4. **Bicep CLI** (comes with Azure CLI)

### 1. Configure GitHub OIDC

Create an Azure AD application and configure federated credentials for GitHub Actions:

```bash
# Create Azure AD application
az ad app create --display-name "TodoList-GitHub-Actions"

# Create service principal
az ad sp create --id <app-id>

# Create federated credential for main branch
az ad app federated-credential create \
    --id <app-id> \
    --parameters '{
        "name": "TodoList-Main",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "repo:your-org/TodoList:ref:refs/heads/main",
        "description": "Main branch deployment",
        "audiences": ["api://AzureADTokenExchange"]
    }'

# Assign Contributor role to service principal
az role assignment create \
    --assignee <service-principal-id> \
    --role "Contributor" \
    --scope "/subscriptions/<subscription-id>"
```

### 2. Configure GitHub Secrets

Add these secrets to your GitHub repository:

```
AZURE_CLIENT_ID: <app-id>
AZURE_TENANT_ID: <tenant-id>
AZURE_SUBSCRIPTION_ID: <subscription-id>
```

### 3. Deploy Infrastructure

#### Option A: GitHub Actions (Recommended)

Push to the appropriate branch to trigger deployment:
- `develop` branch → dev environment
- `staging` branch → staging environment  
- `main` branch → prod environment

#### Option B: Manual Deployment

```bash
# Login to Azure
az login

# Create resource group
az group create --name rg-todolist-dev --location "East US 2"

# Deploy infrastructure
az deployment group create \
    --resource-group rg-todolist-dev \
    --template-file infra/main.bicep \
    --parameters environment=dev \
    --parameters postgresAdminPassword="YourSecurePassword123!"
```

## 🔧 Configuration

### Environment-Specific Settings

Each environment has different resource configurations optimized for its purpose:

| Resource | Dev | Staging | Production |
|----------|-----|---------|------------|
| Container Apps | 0-3 replicas, Basic | 1-5 replicas, Standard | 2-10 replicas, Premium |
| PostgreSQL | Burstable B1ms, 32GB | GeneralPurpose D2s, 128GB | GeneralPurpose D4s, 256GB |
| Container Registry | Basic, Public | Standard, Private | Premium, Private |
| Monitoring Retention | 30 days | 60 days | 90 days |

### Parameter Files

Environment-specific parameters are stored in `parameters/` directory:

- **dev.parameters.json**: Development environment settings
- **staging.parameters.json**: Staging environment settings  
- **prod.parameters.json**: Production environment settings

### Secret Management

Secrets are managed through Azure Key Vault with the following pattern:

- Database credentials stored in Key Vault
- Container Apps access secrets via managed identity
- Role-based access control (RBAC) for secure access
- Automatic secret rotation support

## 🔍 Monitoring & Observability

### Application Insights

- Automatic dependency tracking
- Performance monitoring
- Exception tracking
- Custom metrics and events

### Log Analytics

- Container app logs
- Database audit logs
- Network security group flow logs
- Azure activity logs

### Alerts

Pre-configured alerts for:
- Application availability < 99% (prod) / 95% (dev/staging)
- Response time > 2s (prod) / 5s (dev/staging)
- Failure rate > 5% (prod) / 10% (dev/staging)

### Workbooks

Custom Azure Workbook dashboard includes:
- Request volume and response times
- Error rates and exception details
- Database performance metrics
- Container resource utilization

## 🔒 Security

### Network Security

- Virtual Network with private subnets
- Network Security Groups with restrictive rules
- Private endpoints for all Azure services
- No public internet access to database

### Identity & Access

- User-assigned managed identity for Container Apps
- Azure AD authentication for PostgreSQL
- RBAC for Key Vault access
- Principle of least privilege

### Data Protection

- Encryption in transit (TLS 1.2+)
- Encryption at rest (Azure default)
- Key Vault for secret management
- Private DNS zones for service resolution

## 🚨 Troubleshooting

### Common Issues

1. **Deployment Fails with RBAC Errors**
   ```bash
   # Verify service principal has Contributor role
   az role assignment list --assignee <service-principal-id>
   ```

2. **Container App Cannot Pull Image**
   ```bash
   # Check ACR role assignment
   az role assignment list --scope <acr-resource-id>
   ```

3. **Database Connection Fails**
   ```bash
   # Verify private DNS resolution
   az network private-dns record-set list --zone-name privatelink.postgres.database.azure.com --resource-group <rg-name>
   ```

### Useful Commands

```bash
# View deployment status
az deployment group show --name <deployment-name> --resource-group <rg-name>

# Check container app logs
az containerapp logs show --name <app-name> --resource-group <rg-name>

# Test database connectivity
az postgres flexible-server connect --name <server-name> --admin-user <username>

# Validate Bicep template
az bicep build --file infra/main.bicep
```

## 📚 Additional Resources

- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Azure PostgreSQL Flexible Server](https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/)
- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [GitHub Actions for Azure](https://docs.microsoft.com/en-us/azure/developer/github/github-actions)

## 🤝 Contributing

1. Test changes in dev environment first
2. Use feature branches for infrastructure changes
3. Update parameter files for all environments
4. Document any breaking changes
5. Follow Azure Well-Architected Framework principles

## 📝 License

This infrastructure code is licensed under the same terms as the TodoList application.
