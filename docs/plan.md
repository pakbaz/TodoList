# TodoList Azure Infrastructure and CI/CD Implementation Plan

## Project Overview

Deploy a .NET 9 Blazor Server TodoList application to Azure using Infrastructure as Code (Bicep) and CI/CD (GitHub Actions). The application uses PostgreSQL database and includes MCP (Model Context Protocol) endpoints for AI integration.

## Current Architecture Analysis

Based on the codebase analysis:

- **Technology Stack**: .NET 9, Blazor Server, Entity Framework Core, PostgreSQL with SQLite fallback
- **Containerized**: Docker with multi-stage build, optimized for production
- **Application Features**: 
  - Web UI on port 8080
  - RESTful API endpoints (/mcp/todos)
  - MCP protocol support (/mcp)
  - Health checks (/health)
  - Application Insights integration

## Infrastructure Components

### Azure Resources to Deploy

1. **Resource Group**
   - Environment-specific resource groups (dev, staging, prod)
   - Consistent naming convention and tagging

2. **Azure Container Apps Environment**
   - Shared environment for container apps
   - Log Analytics integration
   - VNet integration for security

3. **Azure Container Apps**
   - Blazor Server application hosting
   - Auto-scaling configuration
   - Session affinity for Blazor Server
   - Health probes configuration

4. **Azure Container Registry (ACR)**
   - Private container image registry
   - Integration with GitHub Actions
   - Image scanning and security

5. **Azure Database for PostgreSQL Flexible Server**
   - Managed PostgreSQL database
   - High availability configuration
   - Automated backups
   - Private endpoint connectivity

6. **Azure Key Vault**
   - Secrets management (connection strings, API keys)
   - Integration with Container Apps using managed identity
   - Certificate management

7. **Azure Application Insights**
   - Application monitoring and telemetry
   - Custom metrics and logging
   - Performance monitoring

8. **Azure Log Analytics Workspace**
   - Centralized logging
   - Integration with Container Apps and other services

## Implementation Phases

### Phase 1: Infrastructure Foundation

1. **Directory Structure Setup**
   ```
   /infra/
   ├── main.bicep                 # Main template orchestrator
   ├── modules/
   │   ├── container-apps-env.bicep    # Container Apps Environment
   │   ├── container-app.bicep         # Container App
   │   ├── container-registry.bicep    # Azure Container Registry
   │   ├── postgresql.bicep            # PostgreSQL Flexible Server
   │   ├── key-vault.bicep            # Key Vault
   │   ├── app-insights.bicep         # Application Insights
   │   └── log-analytics.bicep        # Log Analytics Workspace
   ├── parameters/
   │   ├── main.dev.bicepparam        # Development parameters
   │   ├── main.staging.bicepparam    # Staging parameters
   │   └── main.prod.bicepparam       # Production parameters
   └── scripts/
       ├── deploy.sh                  # Deployment script
       └── cleanup.sh                 # Cleanup script
   ```

2. **Core Infrastructure Templates**
   - Modular Bicep templates for each Azure service
   - Parameter files for environment-specific configurations
   - Output values for inter-template dependencies

### Phase 2: CI/CD Pipeline

1. **GitHub Actions Workflows**
   ```
   /.github/workflows/
   ├── infrastructure.yml          # Infrastructure deployment
   ├── application.yml            # Application build and deploy
   ├── pr-validation.yml          # PR validation and testing
   └── security-scan.yml          # Security scanning
   ```

2. **Authentication Setup**
   - OpenID Connect (OIDC) federation with Azure
   - Service Principal with minimum required permissions
   - GitHub Secrets configuration

3. **Multi-Environment Strategy**
   - Development: Auto-deploy on main branch
   - Staging: Manual approval for production testing
   - Production: Manual approval with additional validations

### Phase 3: Security Implementation

1. **Network Security**
   - Private endpoints for database
   - VNet integration for Container Apps
   - Network Security Groups (NSGs)
   - Application Gateway with WAF (optional)

2. **Identity and Access Management**
   - Managed Identity for Container Apps
   - RBAC assignments
   - Key Vault access policies
   - Azure AD integration

3. **Secrets Management**
   - Store database connection strings in Key Vault
   - Application Insights connection string in Key Vault
   - GitHub Secrets for CI/CD

### Phase 4: Monitoring and Observability

1. **Application Monitoring**
   - Application Insights integration
   - Custom telemetry and metrics
   - Performance monitoring
   - Error tracking and alerting

2. **Infrastructure Monitoring**
   - Azure Monitor integration
   - Log Analytics queries
   - Dashboards and workbooks
   - Alerting rules

## Environment Configuration

### Development Environment
- **Container Apps**: Consumption plan with scale-to-zero
- **Database**: Burstable tier (B1ms) with minimal storage
- **Auto-deployment**: Triggered on main branch push
- **Monitoring**: Basic Application Insights

### Staging Environment
- **Container Apps**: Dedicated plan with moderate scaling
- **Database**: General Purpose tier (D2s) with automated backups
- **Deployment**: Manual trigger for testing
- **Monitoring**: Full Application Insights with custom metrics

### Production Environment
- **Container Apps**: Dedicated plan with high availability
- **Database**: General Purpose tier (D4s) with high availability and geo-redundancy
- **Deployment**: Manual approval with additional validations
- **Monitoring**: Full observability stack with alerting

## Required GitHub Secrets

The following secrets need to be configured in GitHub:

1. **Azure Authentication (OIDC)**
   ```
   AZURE_CLIENT_ID          # Application (client) ID
   AZURE_TENANT_ID          # Directory (tenant) ID  
   AZURE_SUBSCRIPTION_ID    # Azure subscription ID
   ```

2. **Optional Secrets** (if not using managed identity)
   ```
   AZURE_CLIENT_SECRET      # Client secret (if not using OIDC)
   ```

## Deployment Strategy

### Initial Deployment
1. Create Azure service principal with OIDC federation
2. Configure GitHub repository secrets
3. Deploy infrastructure using Bicep templates
4. Build and push container image to ACR
5. Deploy application to Container Apps
6. Configure custom domain and SSL (optional)

### Continuous Deployment
1. Code changes trigger GitHub Actions workflow
2. Build and test application
3. Build and push new container image
4. Deploy to development environment automatically
5. Manual approval for staging and production deployments
6. Health checks and smoke tests post-deployment

## Validation and Testing

### Infrastructure Validation
- Bicep template validation and linting
- Azure Policy compliance checks
- Security baseline validation
- Cost estimation and optimization

### Application Testing
- Unit tests execution
- Integration tests with test database
- Security scanning (SAST/DAST)
- Performance testing
- Health check validation

### Deployment Verification
- Infrastructure deployment verification
- Application health checks
- Database connectivity tests
- Monitoring and alerting validation
- Rollback procedures testing

## Post-Deployment Tasks

### Security Hardening
- Enable diagnostic settings for all resources
- Configure backup and disaster recovery
- Implement monitoring and alerting
- Security review and penetration testing

### Performance Optimization
- Monitor application performance
- Database query optimization
- Resource scaling optimization
- Cost optimization review

### Documentation
- Infrastructure documentation
- Deployment procedures
- Troubleshooting guides
- Operational runbooks

## Success Criteria

1. **Infrastructure**: All Azure resources deployed and configured correctly
2. **Application**: TodoList application accessible and functional
3. **Database**: PostgreSQL database connected and operational
4. **Security**: All security best practices implemented
5. **Monitoring**: Full observability stack operational
6. **CI/CD**: Automated deployment pipeline functional
7. **Testing**: All validation and testing procedures passing

## Timeline Estimate

- **Phase 1 (Infrastructure)**: 2-3 days
- **Phase 2 (CI/CD)**: 1-2 days  
- **Phase 3 (Security)**: 1-2 days
- **Phase 4 (Monitoring)**: 1 day
- **Testing and Validation**: 1-2 days
- **Documentation**: 1 day

**Total Estimated Time**: 7-11 days

## Risk Mitigation

1. **Infrastructure Failures**: Implement infrastructure validation and testing
2. **Security Vulnerabilities**: Regular security scanning and updates
3. **Performance Issues**: Performance testing and monitoring
4. **Cost Overruns**: Cost monitoring and budget alerts
5. **Deployment Failures**: Rollback procedures and health checks
