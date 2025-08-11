# TodoList Azure Infrastructure

## Architecture Overview

This TodoList application is deployed using a modern Azure cloud-native architecture optimized for scalability, security, and cost-effectiveness. The architecture follows Azure Well-Architected Framework principles and Azure Architecture Center best practices.

### Architecture Diagram

```
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐
│                     │    │                      │    │                     │
│  Azure Container    │────│  Azure Database for  │    │  Azure Container    │
│  Apps               │    │  PostgreSQL          │    │  Registry           │
│  (Blazor App)       │    │  Flexible Server     │    │  (Docker Images)    │
│                     │    │                      │    │                     │
└─────────────────────┘    └──────────────────────┘    └─────────────────────┘
           │                           │                           │
           │                           │                           │
           └───────────────────────────┼───────────────────────────┘
                                       │
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐
│                     │    │                      │    │                     │
│  Azure Log          │────│  Application         │    │  Azure Key Vault    │
│  Analytics          │    │  Insights            │    │  (Secrets)          │
│  Workspace          │    │  (Monitoring)        │    │                     │
│                     │    │                      │    │                     │
└─────────────────────┘    └──────────────────────┘    └─────────────────────┘
```

## Azure Services Used

### Core Services

1. **Azure Container Apps**
   - **Purpose**: Host the .NET 9 Blazor Server application
   - **Features**: Auto-scaling, zero-downtime deployments, built-in load balancing
   - **Configuration**: Sticky sessions enabled for Blazor Server state management
   - **Scaling**: CPU and memory-based auto-scaling with min/max replica settings

2. **Azure Database for PostgreSQL Flexible Server**
   - **Purpose**: Primary database for todo items storage
   - **Tier**: Burstable B1ms (1 vCore, 2 GB RAM) for cost optimization
   - **Features**: Automated backups, high availability, automated patching
   - **Security**: Microsoft Entra ID authentication, private networking

3. **Azure Container Registry**
   - **Purpose**: Store and manage Docker container images
   - **Tier**: Basic tier for cost optimization
   - **Features**: Automated image scanning, geo-replication capability

### Supporting Services

4. **Azure Log Analytics Workspace**
   - **Purpose**: Centralized logging and monitoring
   - **Integration**: Container Apps logs, PostgreSQL metrics
   - **Retention**: 30 days for cost optimization

5. **Azure Application Insights**
   - **Purpose**: Application performance monitoring and telemetry
   - **Features**: Request tracing, dependency tracking, custom metrics
   - **Integration**: Built into .NET application via Application Insights SDK

6. **Azure Key Vault**
   - **Purpose**: Secure storage of connection strings and secrets
   - **Features**: Managed identity integration, secret rotation
   - **Access**: Container Apps accesses via system-assigned managed identity

## Security Configuration

### Network Security
- **Private Endpoints**: PostgreSQL accessible only via private network
- **Network Security Groups**: Restrict traffic to necessary ports only
- **Service Endpoints**: Secure communication between Container Apps and PostgreSQL

### Identity and Access Management
- **Managed Identity**: System-assigned managed identity for Container Apps
- **Microsoft Entra ID**: Authentication for PostgreSQL database
- **RBAC**: Least-privilege access to all Azure resources
- **Key Vault Integration**: Secrets accessed via managed identity

### Data Protection
- **Encryption in Transit**: TLS 1.2+ for all connections
- **Encryption at Rest**: Azure-managed keys for database and storage
- **Connection Throttling**: Protection against brute force attacks
- **Firewall Rules**: IP-based access control for PostgreSQL

## Cost Optimization Features

1. **Burstable PostgreSQL Tier**: Cost-effective for variable workloads
2. **Container Apps Consumption Plan**: Pay-per-use scaling model
3. **Basic Container Registry**: Minimal tier for simple use cases
4. **Automated Scaling**: Scale down during low usage periods
5. **Resource Tagging**: Cost tracking and allocation by environment

## High Availability and Reliability

1. **Zone Redundancy**: Available for production environments
2. **Automated Backups**: 7-day retention for PostgreSQL
3. **Health Checks**: Container Apps health monitoring
4. **Rolling Deployments**: Zero-downtime application updates
5. **Retry Policies**: Built-in connection resilience

## Monitoring and Observability

### Application Monitoring
- **Application Insights**: Request/response times, dependency calls
- **Custom Metrics**: Todo item operations, MCP endpoint usage
- **Error Tracking**: Exception logging and alerting

### Infrastructure Monitoring
- **Container Metrics**: CPU, memory, network utilization
- **Database Metrics**: Connection count, query performance
- **Log Aggregation**: Centralized in Log Analytics Workspace

### Alerting
- **High CPU/Memory**: Container resource exhaustion
- **Database Connections**: Connection pool exhaustion
- **Application Errors**: Error rate thresholds
- **Health Check Failures**: Service availability issues

## Deployment Instructions

### Prerequisites
1. Azure CLI installed and configured
2. Terraform CLI installed (v1.0+)
3. Docker installed for local testing
4. Azure subscription with appropriate permissions

### Initial Deployment

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd TodoList/infra
   ```

2. **Configure Terraform variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Initialize and plan**:
   ```bash
   terraform init
   terraform plan
   ```

4. **Deploy infrastructure**:
   ```bash
   terraform apply
   ```

5. **Verify deployment**:
   ```bash
   # Check resource group
   az group list --query "[?name=='rg-todolist-prod'].name" -o table
   
   # Check Container Apps
   az containerapp list --resource-group rg-todolist-prod --query "[].name" -o table
   
   # Check PostgreSQL server
   az postgres flexible-server list --resource-group rg-todolist-prod --query "[].name" -o table
   ```

### Application Deployment

The application is automatically deployed via GitHub Actions CI/CD pipeline:

1. **Trigger**: Push to main branch
2. **Build**: Docker image creation and testing
3. **Push**: Image pushed to Azure Container Registry
4. **Deploy**: Container Apps updated with new image
5. **Verify**: Health checks confirm successful deployment

## Environment Variables

The following environment variables are configured for the application:

### Database Configuration
- `ConnectionStrings__DefaultConnection`: PostgreSQL connection string (from Key Vault)
- `ASPNETCORE_ENVIRONMENT`: Set to "Production"

### Application Configuration
- `ASPNETCORE_URLS`: "http://+:8080"
- `ApplicationInsights__ConnectionString`: App Insights connection string
- `ApplicationInsights__InstrumentationKey`: App Insights instrumentation key

### Security Configuration
- `Azure__KeyVault__VaultUrl`: Key Vault URL for secret access

## CI/CD Pipeline

### GitHub Actions Workflow

The CI/CD pipeline (`.github/workflows/deploy.yml`) includes:

1. **Build Stage**:
   - Checkout code
   - Setup .NET 9 SDK
   - Restore dependencies
   - Build application
   - Run tests

2. **Docker Stage**:
   - Build Docker image
   - Security scan with Trivy
   - Push to Azure Container Registry

3. **Deploy Stage**:
   - Update Container Apps revision
   - Wait for deployment completion
   - Run smoke tests
   - Send notifications

### Pipeline Triggers
- **Push to main**: Full deployment to production
- **Pull Request**: Build and test only
- **Manual**: Triggered via GitHub Actions UI

### Environment Secrets
The following secrets must be configured in GitHub repository settings:
- `AZURE_CLIENT_ID`: Service principal client ID
- `AZURE_CLIENT_SECRET`: Service principal secret
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID
- `AZURE_TENANT_ID`: Azure tenant ID

## Terraform Configuration

### Key Terraform Files

- `main.tf`: Core infrastructure resources
- `variables.tf`: Input variables and configuration
- `outputs.tf`: Resource outputs for reference
- `providers.tf`: Azure provider configuration
- `locals.tf`: Local values and computations

### State Management
- **Backend**: Azure Storage Account (configured in `providers.tf`)
- **State Locking**: Azure Storage Blob lease
- **State File**: Encrypted and versioned

## Troubleshooting

### Common Issues

1. **Container App won't start**:
   ```bash
   # Check logs
   az containerapp logs show --name ca-todolist-prod --resource-group rg-todolist-prod
   
   # Check environment variables
   az containerapp show --name ca-todolist-prod --resource-group rg-todolist-prod --query "properties.configuration.secrets"
   ```

2. **Database connection issues**:
   ```bash
   # Test connectivity
   az postgres flexible-server connect --name psql-todolist-prod --admin-user app_user --database todolistdb
   
   # Check firewall rules
   az postgres flexible-server firewall-rule list --name psql-todolist-prod --resource-group rg-todolist-prod
   ```

3. **Application Insights not receiving data**:
   ```bash
   # Verify instrumentation key
   az monitor app-insights component show --app ai-todolist-prod --resource-group rg-todolist-prod --query "instrumentationKey"
   ```

### Performance Optimization

1. **Scale Container Apps**:
   ```bash
   # Manual scaling
   az containerapp revision set-mode --name ca-todolist-prod --resource-group rg-todolist-prod --mode single
   
   # Update scaling rules
   az containerapp update --name ca-todolist-prod --resource-group rg-todolist-prod --min-replicas 2 --max-replicas 10
   ```

2. **Optimize PostgreSQL**:
   ```bash
   # Scale up compute
   az postgres flexible-server update --name psql-todolist-prod --resource-group rg-todolist-prod --sku-name Standard_B2s
   
   # Enable query store
   az postgres flexible-server parameter set --name psql-todolist-prod --resource-group rg-todolist-prod --name shared_preload_libraries --value pg_stat_statements
   ```

## Security Best Practices Implemented

1. **Network Isolation**: Private endpoints and VNet integration
2. **Identity Management**: Managed identities eliminate credential management
3. **Secret Management**: Key Vault integration with automatic rotation
4. **Data Encryption**: TLS in transit, encryption at rest
5. **Access Control**: RBAC and PostgreSQL role-based permissions
6. **Monitoring**: Security alerts and audit logging
7. **Compliance**: Azure Policy enforcement for security baselines

## Cost Management

### Monthly Cost Estimates (East US region)
- Container Apps (B1ms): ~$15-30/month (depending on usage)
- PostgreSQL Flexible Server (B1ms): ~$12-25/month
- Container Registry (Basic): ~$5/month
- Log Analytics Workspace: ~$2-10/month (depending on ingestion)
- Application Insights: ~$0-5/month (depending on usage)
- Key Vault: ~$1/month

**Total Estimated Monthly Cost**: $35-75/month

### Cost Optimization Tips
1. Use consumption-based scaling for Container Apps
2. Stop PostgreSQL server during non-business hours if applicable
3. Set retention policies for logs and metrics
4. Monitor and right-size resources based on actual usage
5. Use Azure Cost Management alerts and budgets

## Maintenance and Updates

### Regular Maintenance Tasks
1. **Weekly**: Review performance metrics and scaling policies
2. **Monthly**: Update base Docker images and dependencies
3. **Quarterly**: Review and rotate secrets in Key Vault
4. **Annually**: Review and update backup/retention policies

### Security Updates
- Container base images automatically updated via GitHub Actions
- PostgreSQL patches applied during maintenance windows
- Azure services automatically updated by Microsoft

## Support and Documentation

### Additional Resources
- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Azure PostgreSQL Documentation](https://docs.microsoft.com/en-us/azure/postgresql/)
- [Blazor Server Hosting Guidelines](https://docs.microsoft.com/en-us/aspnet/core/blazor/host-and-deploy/server)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### Contact Information
For support with this infrastructure, contact the development team or create an issue in the repository.
