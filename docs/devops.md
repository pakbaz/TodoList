# DevOps Implementation Documentation

This document provides comprehensive information about the Infrastructure as Code (IaC) and CI/CD pipeline implementation for the TodoList application.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Infrastructure Components](#infrastructure-components)
- [CI/CD Pipeline](#cicd-pipeline)
- [GitHub Secrets](#github-secrets)
- [Deployment Process](#deployment-process)
- [Environment Configuration](#environment-configuration)
- [Security](#security)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## Overview

The TodoList application uses a modern DevOps approach with:
- **Infrastructure as Code**: Azure Bicep templates for reproducible infrastructure
- **Containerization**: Docker containers for consistent deployments
- **Serverless Computing**: Azure Container Apps for automatic scaling
- **Managed Services**: Azure PostgreSQL, Key Vault, Container Registry
- **CI/CD Automation**: GitHub Actions for automated deployment
- **Security**: Managed Identity and OIDC authentication

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│  GitHub Actions  │───▶│  Azure Container│
│                 │    │     (CI/CD)      │    │      Apps       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                ▲                        │
                                │                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Docker Image   │◀───│ Azure Container  │    │  Azure Key      │
│                 │    │    Registry      │    │     Vault       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │  Azure          │
                                               │  PostgreSQL     │
                                               └─────────────────┘
```

## Infrastructure Components

### 1. Log Analytics Workspace
- **Purpose**: Centralized logging and monitoring
- **Features**: Log retention, custom queries, alerts
- **Configuration**: Environment-specific retention periods

### 2. Application Insights
- **Purpose**: Application performance monitoring
- **Features**: Request tracking, dependency monitoring, custom telemetry
- **Integration**: Connected to Log Analytics workspace

### 3. Azure Key Vault
- **Purpose**: Secure storage of secrets and connection strings
- **Features**: RBAC access control, audit logging, automatic rotation support
- **Secrets Stored**:
  - Database connection strings
  - Application Insights connection string

### 4. Azure Container Registry
- **Purpose**: Private Docker image storage
- **Features**: Geo-replication, vulnerability scanning, managed identity access
- **Security**: RBAC-based access for Container Apps

### 5. Azure PostgreSQL Flexible Server
- **Purpose**: Managed database service
- **Features**: High availability, automatic backups, performance insights
- **Configuration**: Environment-specific SKUs and storage

### 6. Azure Container Apps
- **Purpose**: Serverless container hosting
- **Features**: Auto-scaling, session affinity, managed identity
- **Configuration**: Environment-specific replica counts

## CI/CD Pipeline

The GitHub Actions workflow (`/.github/workflows/deploy.yml`) implements a complete CI/CD pipeline:

### Workflow Stages

1. **Validation**
   - Bicep template validation
   - Security scanning
   - Dependency checks

2. **Build**
   - Docker image build
   - Multi-stage build optimization
   - Image tagging with commit SHA

3. **Test**
   - Unit tests execution
   - Integration tests
   - Code coverage reporting

4. **Deploy Infrastructure**
   - Bicep template deployment
   - Resource group creation
   - Environment-specific parameters

5. **Deploy Application**
   - Container image push
   - Container app revision deployment
   - Health checks validation

### Environment Strategy

- **Development**: Triggered on every push to main
- **Staging**: Triggered on release creation
- **Production**: Manual approval required

## GitHub Secrets

The following secrets must be configured in your GitHub repository:

### Required Secrets

1. **AZURE_CLIENT_ID**
   - **Description**: Service Principal Client ID for OIDC authentication
   - **Purpose**: Authenticate GitHub Actions with Azure
   - **Format**: UUID (e.g., `12345678-1234-1234-1234-123456789012`)

2. **AZURE_TENANT_ID**
   - **Description**: Azure AD Tenant ID
   - **Purpose**: Specify the Azure AD tenant for authentication
   - **Format**: UUID (e.g., `87654321-4321-4321-4321-210987654321`)

3. **AZURE_SUBSCRIPTION_ID**
   - **Description**: Azure Subscription ID where resources will be deployed
   - **Purpose**: Target subscription for resource deployment
   - **Format**: UUID (e.g., `11111111-2222-3333-4444-555555555555`)

4. **POSTGRES_ADMIN_PASSWORD**
   - **Description**: PostgreSQL administrator password
   - **Purpose**: Database authentication
   - **Requirements**: 
     - Minimum 8 characters
     - Must contain uppercase, lowercase, number, and special character
     - No SQL keywords

### Setting Up Secrets

```bash
# Set the GitHub secrets using GitHub CLI
gh secret set AZURE_CLIENT_ID --body "your-client-id"
gh secret set AZURE_TENANT_ID --body "your-tenant-id"
gh secret set AZURE_SUBSCRIPTION_ID --body "your-subscription-id"
gh secret set POSTGRES_ADMIN_PASSWORD --body "your-secure-password"
```

### Environment Variables

The following environment variables are configured automatically:

- `AZURE_RESOURCE_GROUP`: Target resource group name
- `AZURE_LOCATION`: Deployment region
- `CONTAINER_REGISTRY`: Container registry name
- `ENVIRONMENT`: Deployment environment (dev/staging/prod)

## Deployment Process

### Initial Setup

1. **Fork/Clone Repository**
   ```bash
   git clone https://github.com/your-username/TodoList.git
   cd TodoList
   ```

2. **Configure Azure Service Principal**
   ```bash
   # Create service principal with OIDC
   az ad sp create-for-rbac --name "TodoList-GitHub-Actions" \
     --role contributor \
     --scopes /subscriptions/{subscription-id} \
     --create-cert
   ```

3. **Set GitHub Secrets**
   - Use the GitHub web interface or CLI to set required secrets

4. **Trigger Deployment**
   ```bash
   git push origin main  # Triggers development deployment
   ```

### Manual Deployment

You can also deploy manually using Azure CLI:

```bash
# Deploy infrastructure
az deployment group create \
  --resource-group todolist-dev-rg \
  --template-file infra/main.bicep \
  --parameters @infra/parameters/dev.parameters.json \
  --parameters postgresAdminPassword="YourSecurePassword"

# Build and push container
docker build -t todolist-app .
az acr login --name your-registry
docker tag todolist-app your-registry.azurecr.io/todolist-app:latest
docker push your-registry.azurecr.io/todolist-app:latest
```

## Environment Configuration

### Development
- **Purpose**: Development and testing
- **Resources**: Minimal SKUs, auto-scaling to zero
- **Database**: Standard_B1ms, 32GB storage
- **Replicas**: 0-3 (scales to zero when idle)

### Staging
- **Purpose**: Pre-production testing
- **Resources**: Medium SKUs, limited scaling
- **Database**: Standard_D2s_v3, 64GB storage
- **Replicas**: 1-5 (always running)

### Production
- **Purpose**: Live application
- **Resources**: High-performance SKUs, zone redundancy
- **Database**: Standard_D4s_v3, 128GB storage, HA enabled
- **Replicas**: 2-10 (always running, multiple zones)

## Security

### Authentication & Authorization
- **OIDC Authentication**: No long-lived secrets for GitHub Actions
- **Managed Identity**: Container Apps access resources without passwords
- **RBAC**: Least-privilege access to Azure resources
- **Key Vault**: Secure storage of sensitive configuration

### Network Security
- **Private Endpoints**: Database accessible only from Container Apps
- **HTTPS Enforcement**: All traffic encrypted in transit
- **Container Registry**: Private registry with RBAC access

### Secrets Management
- **Key Vault Integration**: All secrets stored in Azure Key Vault
- **Automatic Rotation**: Support for secret rotation
- **Audit Logging**: All secret access logged and monitored

## Monitoring

### Application Insights
- **Request Tracking**: HTTP request metrics and traces
- **Dependency Monitoring**: Database and external service calls
- **Custom Telemetry**: Application-specific metrics
- **Alerts**: Automated alerting on performance issues

### Log Analytics
- **Centralized Logging**: All application and infrastructure logs
- **Custom Queries**: KQL queries for troubleshooting
- **Dashboards**: Visual monitoring dashboards
- **Log Retention**: Environment-specific retention policies

### Health Checks
- **Liveness Probe**: Container health validation
- **Readiness Probe**: Application startup validation
- **Database Health**: Connection and query validation

## Troubleshooting

### Common Issues

1. **Deployment Failures**
   ```bash
   # Check deployment status
   az deployment group show --resource-group todolist-dev-rg --name main-deployment
   
   # View deployment logs
   az monitor activity-log list --resource-group todolist-dev-rg
   ```

2. **Container App Issues**
   ```bash
   # Check container app status
   az containerapp show --name todolist-dev-app --resource-group todolist-dev-rg
   
   # View application logs
   az containerapp logs show --name todolist-dev-app --resource-group todolist-dev-rg
   ```

3. **Database Connectivity**
   ```bash
   # Test database connection
   psql "host=todolist-dev-db.postgres.database.azure.com user=todolistadmin dbname=todolistdb sslmode=require"
   ```

### Debug Commands

```bash
# List all resources in resource group
az resource list --resource-group todolist-dev-rg --output table

# Check Key Vault secrets
az keyvault secret list --vault-name todolist-dev-kv-xxxxx

# View container app revisions
az containerapp revision list --name todolist-dev-app --resource-group todolist-dev-rg

# Check GitHub Actions run
gh run list --repo your-username/TodoList
gh run view --repo your-username/TodoList <run-id>
```

### Performance Optimization

1. **Container App Scaling**
   - Monitor CPU and memory usage
   - Adjust min/max replicas based on load patterns
   - Configure custom scaling rules

2. **Database Performance**
   - Monitor query performance in Application Insights
   - Optimize database indexes
   - Consider read replicas for high-traffic scenarios

3. **Cost Optimization**
   - Use development environment auto-scaling to zero
   - Monitor resource utilization
   - Implement resource tagging for cost tracking

## Next Steps

1. **Enhanced Monitoring**: Set up custom dashboards and alerts
2. **Disaster Recovery**: Implement backup and restore procedures
3. **Performance Testing**: Add load testing to the CI/CD pipeline
4. **Security Scanning**: Integrate container vulnerability scanning
5. **Blue-Green Deployment**: Implement zero-downtime deployment strategies

## Support

For issues and questions:
- Check Application Insights for application errors
- Review GitHub Actions workflow logs
- Consult Azure documentation for service-specific issues
- Use Azure Support for infrastructure problems
