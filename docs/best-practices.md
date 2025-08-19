# Azure DevOps Best Practices - TodoList Application

## Infrastructure as Code (IaC) with Bicep

### Core Principles
- **Modular Design**: Use separate Bicep modules for each Azure service (ACR, ACA, Key Vault, Database, Networking)
- **Parameter-driven**: Leverage parameters for environment-specific configurations and avoid hardcoded values
- **Secure by Default**: Mark sensitive parameters with `@secure()` decorator and store secrets in Key Vault
- **Naming Conventions**: Use consistent resource naming with environment prefixes and unique suffixes

### Azure Container Apps (ACA) Best Practices
- **Internal Environment**: Deploy ACA in internal mode with VNet integration for enhanced security
- **Managed Identity**: Use user-assigned managed identities for secure authentication to Azure resources
- **Scaling Rules**: Configure appropriate min/max replica counts and scaling triggers based on workload
- **Health Probes**: Implement startup, readiness, and liveness probes for reliable container health monitoring
- **Resource Limits**: Set appropriate CPU and memory limits to prevent resource contention

### Azure Container Registry (ACR) Security
- **Disable Admin User**: Never enable admin user credentials for production environments
- **Managed Identity Authentication**: Use managed identities for image pull operations instead of admin credentials
- **Role-Based Access**: Assign least-privilege roles (AcrPull for pull-only, AcrPush for CI/CD pipelines)
- **Private Networking**: Configure private endpoints for secure registry access
- **Vulnerability Scanning**: Enable Microsoft Defender for Containers for image security scanning

### Key Vault Integration
- **Secret References**: Store database credentials and sensitive configuration in Key Vault
- **Managed Identity Access**: Grant Container Apps managed identity access to Key Vault secrets
- **Secret Rotation**: Implement automated secret rotation where possible
- **Audit Logging**: Enable Key Vault logging for security compliance and monitoring

### Networking Security
- **VNet Integration**: Deploy all resources within a custom virtual network
- **Private Endpoints**: Use private endpoints for database and Key Vault connectivity
- **Network Security Groups**: Configure NSG rules to restrict traffic to necessary ports and protocols
- **Application Gateway**: Use Application Gateway with WAF for public-facing applications
- **Internal Load Balancer**: Route traffic through internal load balancers for enhanced security

### Database Security (PostgreSQL)
- **Private Access**: Configure database with private endpoint and disable public access
- **Firewall Rules**: Restrict database access to specific IP ranges or VNet subnets
- **SSL/TLS Encryption**: Enforce SSL connections for data in transit
- **Backup Strategy**: Configure automated backups with appropriate retention policies
- **Monitoring**: Enable database monitoring and alerting for performance and security

## CI/CD Pipeline Best Practices

### GitHub Actions Security
- **OIDC Authentication**: Use OpenID Connect for secure, keyless authentication between GitHub and Azure
- **Least Privilege**: Grant minimal required permissions to service principals and managed identities
- **Pin Action Versions**: Use specific version tags for GitHub Actions to ensure reproducibility
- **Secret Management**: Store secrets in GitHub encrypted secrets and avoid exposing them in logs
- **Branch Protection**: Implement branch protection rules and require PR reviews for production deployments

### Container Image Management
- **Immutable Tags**: Use Git SHA-based tags for container images to ensure immutability
- **Multi-stage Builds**: Optimize Dockerfile with multi-stage builds to reduce image size
- **Non-root User**: Run containers as non-root users for enhanced security
- **Vulnerability Scanning**: Integrate container scanning in CI pipeline before deployment
- **Image Registry**: Store images in private container registry with appropriate access controls

### Deployment Strategies
- **Environment Separation**: Use separate environments (dev, staging, production) with appropriate controls
- **Rolling Deployments**: Leverage ACA revision management for zero-downtime deployments
- **Health Checks**: Implement comprehensive health checks before marking deployments as successful
- **Rollback Strategy**: Maintain ability to quickly rollback to previous working revisions
- **Monitoring**: Implement comprehensive monitoring and alerting for deployment health

### Infrastructure Deployment
- **Validation**: Use `bicep build` and `what-if` operations to validate templates before deployment
- **Incremental Deployments**: Use incremental deployment mode to avoid unintended resource deletions
- **Resource Locks**: Apply resource locks to critical resources to prevent accidental deletion
- **Change Management**: Track infrastructure changes through version control and deployment logs

## Monitoring and Observability

### Application Insights Integration
- **Telemetry Collection**: Configure Application Insights for comprehensive application monitoring
- **Custom Metrics**: Implement custom metrics for business-specific monitoring requirements
- **Log Correlation**: Ensure proper correlation IDs for distributed tracing across services
- **Performance Monitoring**: Monitor application performance metrics and set up appropriate alerts

### Log Analytics Workspace
- **Centralized Logging**: Route all logs to a central Log Analytics workspace
- **Log Retention**: Configure appropriate log retention policies based on compliance requirements
- **Query Optimization**: Create efficient KQL queries for monitoring and alerting
- **Security Logs**: Capture security-related events for compliance and incident response

### Azure Monitor Integration
- **Metric Alerts**: Set up metric-based alerts for critical performance indicators
- **Action Groups**: Configure action groups for appropriate notification channels
- **Dashboard Creation**: Create comprehensive dashboards for operational visibility
- **Cost Monitoring**: Implement cost monitoring and alerting for budget management

## Security and Compliance

### Identity and Access Management
- **Managed Identities**: Use managed identities wherever possible to eliminate credential management
- **RBAC**: Implement role-based access control with least-privilege principles
- **Conditional Access**: Apply conditional access policies where supported
- **Regular Reviews**: Conduct regular access reviews and permission audits

### Data Protection
- **Encryption at Rest**: Ensure all data is encrypted at rest using Azure-managed keys
- **Encryption in Transit**: Enforce TLS/SSL for all data transmission
- **Key Management**: Use Azure Key Vault for centralized key and secret management
- **Data Classification**: Classify and label sensitive data appropriately

### Network Security
- **Defense in Depth**: Implement multiple layers of network security controls
- **Zero Trust**: Apply zero trust principles to network access and communication
- **Traffic Inspection**: Use Azure Firewall or NVA for traffic inspection and filtering
- **DDoS Protection**: Enable DDoS protection for public-facing resources

This document serves as the foundation for implementing secure, scalable, and maintainable Azure infrastructure for the TodoList application.
