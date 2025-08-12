# Azure DevOps Best Practices for TodoList Application

## Overview
This document outlines the best practices for deploying and managing the TodoList ASP.NET Core application on Azure using Infrastructure as Code (IaC) and CI/CD pipelines.

## Azure Container Apps Best Practices

### Security
- **Managed Identities**: Use system-assigned managed identities for Azure resource authentication, eliminating credential management
- **Private Networking**: Deploy Container Apps in internal mode with VNet injection for isolation from public internet
- **Key Vault Integration**: Store sensitive configuration and secrets in Azure Key Vault with managed identity access
- **HTTPS Enforcement**: Configure Envoy proxy to redirect all HTTP traffic to HTTPS
- **Network Security Groups**: Use NSG rules to control traffic access to internal container apps endpoints
- **Container Security**: Use minimal, hardened base images and run containers as non-root users

### Architecture
- **Single App Instance**: Serve both web UI and MCP endpoints from one container app for simplified architecture
- **Health Probes**: Configure appropriate startup, liveness, and readiness probes with generous initial delays
- **Resource Allocation**: Set CPU and memory limits based on application requirements and monitor usage
- **Auto-scaling**: Configure horizontal pod autoscaling based on CPU, memory, or custom metrics

### Networking
- **Internal Environment**: Use internal Container Apps environment for enhanced security
- **Application Gateway**: Use Azure Application Gateway with WAF for public-facing applications
- **User-Defined Routes**: Control outbound traffic through Azure Firewall or NAT Gateway
- **Service Discovery**: Leverage built-in service discovery for inter-service communication

## Azure PostgreSQL Best Practices

### Security
- **Private Endpoints**: Configure private endpoints to restrict database access to VNet
- **Firewall Rules**: Use database-level firewall rules to control access
- **SSL/TLS**: Enforce SSL connections for data in transit
- **Managed Identity Authentication**: Use managed identities for database authentication when possible

### Performance
- **Connection Pooling**: Configure appropriate connection pooling in application
- **Backup Strategy**: Configure automated backups with appropriate retention
- **High Availability**: Enable zone-redundant high availability for production workloads

## Azure Key Vault Best Practices

### Access Control
- **RBAC**: Use Azure RBAC for fine-grained access control
- **Access Policies**: Configure least-privilege access policies for applications
- **Network Access**: Restrict network access to Key Vault from trusted networks only

### Secret Management
- **Secret Rotation**: Implement automated secret rotation where possible
- **Versioning**: Use Key Vault versioning for secret lifecycle management
- **Monitoring**: Enable logging and monitoring for all Key Vault operations

## Infrastructure as Code (Bicep) Best Practices

### Structure
- **Modular Design**: Use separate Bicep modules for different resource types
- **Parameter Files**: Use parameter files for environment-specific configurations
- **Template Validation**: Always validate templates before deployment

### Security
- **Secure Parameters**: Mark sensitive parameters with `@secure` decorator
- **Outputs**: Avoid outputting sensitive information from templates
- **Resource Names**: Use consistent naming conventions with environment prefixes

### Deployment
- **What-if Analysis**: Use what-if deployments to preview changes
- **Incremental Mode**: Use incremental deployment mode for resource updates
- **Rollback Strategy**: Maintain rollback capabilities using template versioning

## GitHub Actions CI/CD Best Practices

### Security
- **OIDC Authentication**: Use OpenID Connect for secure authentication to Azure
- **Least Privilege**: Configure minimal required permissions for workflows
- **Secret Management**: Store sensitive values in GitHub secrets or Azure Key Vault
- **Environment Protection**: Use environment protection rules for production deployments

### Workflow Design
- **Separation of Concerns**: Separate CI and CD into different workflows
- **Conditional Deployment**: Deploy only on successful tests and code quality checks
- **Multi-Environment**: Support multiple environments (dev, staging, production)
- **Immutable Images**: Tag container images with commit SHA for immutability

### Performance
- **Caching**: Cache dependencies and build artifacts to reduce build times
- **Parallel Jobs**: Run independent jobs in parallel where possible
- **Self-Hosted Runners**: Consider self-hosted runners for private network access

## Monitoring and Observability

### Application Insights
- **Telemetry**: Emit custom telemetry for business metrics
- **Performance Monitoring**: Monitor application performance and dependencies
- **Error Tracking**: Implement comprehensive error tracking and alerting

### Log Analytics
- **Centralized Logging**: Send all logs to centralized Log Analytics workspace
- **Log Retention**: Configure appropriate log retention policies
- **Custom Queries**: Create custom KQL queries for application-specific monitoring

### Health Monitoring
- **Health Endpoints**: Implement comprehensive health check endpoints
- **Synthetic Monitoring**: Use Application Insights availability tests
- **Alerting**: Configure proactive alerting based on application metrics

## Deployment Strategy

### Blue-Green Deployment
- **ACA Revisions**: Use Container Apps revisions for blue-green deployments
- **Traffic Splitting**: Gradually shift traffic between revisions
- **Rollback**: Maintain ability to quickly rollback to previous revision

### Database Migrations
- **Migration Scripts**: Use Entity Framework migrations for database changes
- **Backward Compatibility**: Ensure migrations are backward compatible during deployment
- **Backup Before Migration**: Always backup database before applying migrations

## Cost Optimization

### Resource Sizing
- **Right-sizing**: Monitor and adjust resource allocations based on actual usage
- **Auto-scaling**: Configure auto-scaling to handle load variations efficiently
- **Reserved Instances**: Use reserved instances for predictable workloads

### Resource Management
- **Resource Tagging**: Implement consistent resource tagging for cost tracking
- **Lifecycle Management**: Configure lifecycle policies for storage and backups
- **Cost Monitoring**: Set up cost alerts and budgets for resource groups

## Compliance and Governance

### Policy Management
- **Azure Policy**: Implement Azure policies to enforce compliance requirements
- **Resource Naming**: Follow consistent naming conventions across all resources
- **Resource Governance**: Use Azure Management Groups for enterprise-scale governance

### Audit and Compliance
- **Activity Logging**: Enable Azure Activity Log for all resource operations
- **Compliance Reporting**: Regular compliance assessments and reporting
- **Data Protection**: Implement data classification and protection policies
