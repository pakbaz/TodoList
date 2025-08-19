# Infrastructure and CI/CD Implementation Plan

## Overview
This plan outlines the implementation of Azure Infrastructure as Code (IaC) and CI/CD pipelines for the TodoList ASP.NET Core application using Azure Container Apps.

## Target Azure Resources

### Core Infrastructure
- **Resource Group**: Container for all application resources
- **Azure Container Registry (ACR)**: Private container image storage
- **Azure Container Apps Environment**: Managed container runtime environment
- **Azure Container App**: Application deployment target
- **Log Analytics Workspace**: Centralized logging and monitoring
- **Application Insights**: Application performance monitoring

### Database
- **Azure Database for PostgreSQL**: Primary database service (Flexible Server)
- **Private Endpoint**: Secure database connectivity

### Security & Networking
- **Azure Key Vault**: Secrets and certificate management
- **Virtual Network**: Isolated network environment
- **Subnets**: Segmented network for different service tiers
- **Network Security Groups**: Traffic filtering and access control
- **User-Assigned Managed Identity**: Secure service-to-service authentication

### Optional (Production Hardening)
- **Azure Application Gateway**: Public ingress with Web Application Firewall (WAF)
- **Azure Firewall**: Outbound traffic inspection and control

## Bicep Module Architecture

### Module Structure
```
/infra
├── main.bicep                 # Orchestrator template
├── parameters/
│   ├── dev.bicepparam        # Development environment parameters
│   ├── staging.bicepparam    # Staging environment parameters
│   └── prod.bicepparam       # Production environment parameters
└── modules/
    ├── resource-group.bicep   # Resource group (if deploying at subscription scope)
    ├── networking.bicep       # VNet, subnets, NSGs
    ├── log-analytics.bicep    # Log Analytics workspace
    ├── key-vault.bicep        # Key Vault with access policies
    ├── container-registry.bicep # ACR with private endpoint
    ├── database.bicep         # PostgreSQL with private endpoint
    ├── container-apps-env.bicep # ACA Environment
    ├── container-app.bicep    # ACA Application
    └── app-gateway.bicep      # Application Gateway (optional)
```

### Key Parameters
- `appName`: Application identifier (e.g., "todolist")
- `environment`: Deployment environment ("dev", "staging", "prod")
- `location`: Azure region
- `imageTag`: Container image tag (GitHub SHA)
- `databaseAdminUsername`: PostgreSQL admin username
- `tags`: Resource tagging for governance

## CI/CD Pipeline Design

### GitHub Actions Workflows

#### 1. Continuous Integration (`ci.yml`)
**Triggers**: Pull requests, pushes to feature branches
**Jobs**:
- **Build & Test**:
  - Checkout code
  - Setup .NET 9.0
  - Restore dependencies
  - Run unit tests
  - Generate test coverage reports
- **Container Build**:
  - Authenticate to Azure using OIDC
  - Login to ACR using managed identity
  - Build Docker image with Git SHA tag
  - Push image to ACR
  - Output image tag for CD workflow

#### 2. Continuous Deployment (`cd.yml`)
**Triggers**: Push to `main` branch, manual workflow dispatch
**Environments**: `staging`, `production` (with protection rules)
**Jobs**:
- **Infrastructure Deployment**:
  - Authenticate to Azure using OIDC
  - Deploy Bicep templates with environment-specific parameters
  - Validate deployment using `what-if` operations
- **Application Deployment**:
  - Update Container App with new image tag
  - Monitor deployment health
  - Run post-deployment smoke tests
- **Rollback Strategy**:
  - Automatic rollback on health check failures
  - Manual rollback capability via ACA revisions

### Deployment Environments

#### Development
- **Resource Tier**: Basic/Standard SKUs
- **Scaling**: Manual scaling, minimal replicas
- **Security**: Simplified setup for development speed
- **Database**: Burstable tier with minimal storage

#### Staging
- **Resource Tier**: Standard SKUs
- **Scaling**: Auto-scaling enabled
- **Security**: Production-like security controls
- **Database**: General Purpose tier with replica

#### Production
- **Resource Tier**: Premium SKUs for high availability
- **Scaling**: Advanced auto-scaling with multiple metrics
- **Security**: Full security controls and monitoring
- **Database**: Memory Optimized tier with HA and backups

## Security Implementation

### OIDC Authentication Setup
- **GitHub Repository**: Configure federated credentials
- **Azure Service Principal**: Least-privilege permissions
- **Environment Secrets**: Store Azure tenant/subscription IDs

### Managed Identity Strategy
- **User-Assigned Identity**: Single identity for all ACA operations
- **Role Assignments**:
  - `AcrPull` on Container Registry
  - `Key Vault Secrets User` on Key Vault
  - `Contributor` on Resource Group (deployment only)

### Secret Management
- **Database Credentials**: Generated and stored in Key Vault
- **Application Settings**: Retrieved from Key Vault via secret references
- **Connection Strings**: Built dynamically using Key Vault secrets

## Monitoring and Observability

### Logging Strategy
- **Application Logs**: Structured logging to stdout/stderr
- **Infrastructure Logs**: Azure resource diagnostics to Log Analytics
- **Security Logs**: Key Vault access logs, NSG flow logs

### Metrics and Alerting
- **Application Performance**: Response times, error rates, throughput
- **Infrastructure Health**: Resource utilization, availability
- **Security Events**: Failed authentication attempts, unusual access patterns

### Dashboards
- **Operational Dashboard**: Real-time application health
- **Security Dashboard**: Security posture and compliance
- **Cost Dashboard**: Resource costs and optimization opportunities

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1)
1. Create Bicep modules for networking and security foundation
2. Deploy Log Analytics and Key Vault
3. Setup Container Registry with managed identity authentication
4. Validate infrastructure deployment with what-if operations

### Phase 2: Application Platform (Week 2)
1. Deploy Container Apps Environment with VNet integration
2. Create Container App with basic configuration
3. Setup database with private endpoint connectivity
4. Test end-to-end application deployment

### Phase 3: CI/CD Integration (Week 2)
1. Configure GitHub OIDC authentication
2. Implement CI pipeline for build and test
3. Create CD pipeline for infrastructure and application deployment
4. Setup environment protection rules and approvals

### Phase 4: Production Hardening (Week 3)
1. Add Application Gateway with WAF (if needed)
2. Implement comprehensive monitoring and alerting
3. Setup backup and disaster recovery procedures
4. Conduct security review and penetration testing

## Success Criteria

### Technical Goals
- **Zero-downtime deployments**: Leverage ACA revision management
- **Infrastructure as Code**: 100% infrastructure defined in Bicep
- **Security**: No secrets in code repositories or CI/CD logs
- **Monitoring**: Comprehensive observability across all tiers

### Operational Goals
- **Deployment Speed**: Infrastructure deployment under 10 minutes
- **Rollback Time**: Rollback capability within 2 minutes
- **Reliability**: 99.9% uptime SLA for production environment
- **Cost Optimization**: Resource costs within defined budget thresholds

## Risk Mitigation

### Technical Risks
- **Container Registry Access**: Implement retry logic and fallback mechanisms
- **Database Connectivity**: Use connection pooling and health checks
- **Scaling Issues**: Configure appropriate limits and monitoring

### Operational Risks
- **Failed Deployments**: Automated rollback and monitoring
- **Security Breaches**: Least-privilege access and audit logging
- **Cost Overruns**: Budget alerts and resource optimization

This implementation plan provides a structured approach to deploying a secure, scalable, and maintainable Azure infrastructure for the TodoList application.
