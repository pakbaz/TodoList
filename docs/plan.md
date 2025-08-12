# Implementation Plan - TodoList Azure IaC & CI/CD

## Project Analysis

### Current Architecture
- **Application**: ASP.NET Core 9.0 Blazor Server application with MCP API endpoints
- **Database**: PostgreSQL with SQLite fallback, Entity Framework Core
- **Containerization**: Docker with multi-stage build, runs on port 8080
- **Dependencies**: Application Insights, Health Checks, Entity Framework

### Target Azure Resources

#### Core Infrastructure
- **Resource Group**: todolist-rg-{environment}
- **Azure Container Registry**: todolistacr{environment}
- **Azure Container Apps Environment**: todolist-env-{environment}
- **Azure Container App**: todolist-app-{environment}
- **Azure PostgreSQL Flexible Server**: todolist-db-{environment}
- **Azure Key Vault**: todolist-kv-{environment}
- **Log Analytics Workspace**: todolist-logs-{environment}

#### Networking (Optional - Phase 2)
- **Virtual Network**: todolist-vnet-{environment}
- **Application Gateway**: todolist-agw-{environment}
- **Network Security Group**: todolist-nsg-{environment}

## Bicep Modules Structure

### Main Orchestrator
- **File**: `/infra/main.bicep`
- **Purpose**: Orchestrates all module deployments
- **Parameters**: Environment, location, app name, image tag

### Module List
1. **`rg.bicep`** - Resource group creation (if deploying at subscription scope)
2. **`log-analytics.bicep`** - Log Analytics workspace
3. **`keyvault.bicep`** - Azure Key Vault with access policies
4. **`acr.bicep`** - Azure Container Registry with managed identity access
5. **`postgresql.bicep`** - Azure PostgreSQL Flexible Server with private endpoint
6. **`aca-env.bicep`** - Container Apps Environment with Log Analytics integration
7. **`aca-app.bicep`** - Container App with image, environment variables, secrets

### Parameter Strategy
- **Global Parameters**: `appName`, `environment`, `location`
- **Resource-Specific**: `acrName`, `imageTag`, `postgresqlVersion`
- **Secure Parameters**: Database passwords (generated), Key Vault secrets
- **Environment Files**: `parameters-dev.json`, `parameters-prod.json`

## CI/CD Pipeline Strategy

### Workflow Structure
1. **CI Pipeline** (`ci.yml`)
   - **Triggers**: Pull requests, pushes to feature branches
   - **Jobs**: Build → Test → Package → Push to ACR
   - **Outputs**: Container image tag (commit SHA)

2. **CD Pipeline** (`cd.yml`)
   - **Triggers**: Push to main branch, manual workflow dispatch
   - **Environments**: staging, production
   - **Jobs**: Deploy Infrastructure → Deploy Application → Health Check

### Environment Configuration
- **Staging**: Auto-deploy from main branch
- **Production**: Manual approval required
- **Environment Variables**: Subscription ID, Resource Group, ACR name
- **Secrets**: Managed via GitHub environments and Azure Key Vault

## Security Implementation

### Authentication Strategy
- **GitHub to Azure**: OIDC with service principal (no secrets)
- **Container App to Azure Resources**: System-assigned managed identity
- **Database Authentication**: PostgreSQL admin + managed identity (future)
- **Container Registry**: Managed identity for image pulls

### Secret Management Flow
1. **Build Secrets**: None required (OIDC authentication)
2. **Application Secrets**: Stored in Azure Key Vault
3. **Database Connection**: Key Vault reference in Container App
4. **Certificate Management**: Azure-managed certificates for HTTPS

### Network Security (Phase 2)
- **Container Apps Environment**: Internal mode with VNet injection
- **Database**: Private endpoint within VNet
- **Public Access**: Application Gateway with WAF

## Deployment Phases

### Phase 1: Basic Deployment
- [x] Public Container Apps Environment
- [x] Public PostgreSQL with firewall rules
- [x] Basic CI/CD pipeline
- [x] GitHub OIDC authentication

### Phase 2: Enhanced Security
- [ ] VNet integration with private endpoints
- [ ] Application Gateway with WAF
- [ ] Network Security Groups
- [ ] Enhanced monitoring and alerting

## Parameters and Configuration

### Environment-Specific Parameters
```json
{
  "appName": "todolist",
  "environment": "dev|staging|prod",
  "location": "East US",
  "acrName": "todolistacr",
  "postgresqlServerName": "todolist-db",
  "keyVaultName": "todolist-kv"
}
```

### Container App Configuration
- **CPU**: 0.25 cores
- **Memory**: 0.5Gi
- **Min Replicas**: 1
- **Max Replicas**: 5
- **Scale Rules**: CPU and HTTP request based

### PostgreSQL Configuration
- **SKU**: Standard_B1ms (basic tier for dev)
- **Storage**: 32GB with auto-grow
- **Backup Retention**: 7 days
- **Version**: 15

## Rollback Strategy

### Container Apps Revisions
- **Blue-Green Deployment**: Use revision mode for zero-downtime deployments
- **Traffic Splitting**: Gradually shift traffic to new revision
- **Automatic Rollback**: Revert to previous revision on health check failure

### Database Migrations
- **Backward Compatibility**: Ensure migrations are backward compatible
- **Backup Strategy**: Automated backup before migration
- **Manual Rollback**: Manual database restore if needed

## Testing and Verification

### Pre-Deployment Validation
- **Bicep Linting**: Built-in Bicep validation
- **What-if Analysis**: Preview resource changes
- **Resource Naming**: Validate naming conventions

### Post-Deployment Verification
- **Health Endpoints**: Application `/health` endpoint check
- **Database Connectivity**: Test database connection
- **Application Functionality**: Basic smoke tests
- **Log Analytics**: Verify log ingestion

### Performance Testing
- **Load Testing**: Azure Load Testing for scale verification
- **Resource Monitoring**: CPU, memory, and request metrics
- **Database Performance**: Connection pool and query performance

## Implementation Timeline

### Week 1: Foundation
- [x] Bicep module development
- [x] GitHub Actions workflow creation
- [x] OIDC configuration
- [x] Basic deployment to development environment

### Week 2: Testing & Refinement
- [ ] Integration testing
- [ ] Security hardening
- [ ] Performance optimization
- [ ] Documentation completion

### Week 3: Production Deployment
- [ ] Production environment setup
- [ ] Production deployment
- [ ] Monitoring configuration
- [ ] Team training and handover
