# Deployment Setup Guide

## Current Status
✅ **Infrastructure Code**: All Bicep files are ready and validated
✅ **CI/CD Pipelines**: GitHub Actions workflows are configured  
✅ **Code Quality**: All files are properly formatted and error-free
❌ **Azure Authentication**: Needs manual configuration

## Required GitHub Secrets and Variables

### Step 1: Create Azure Service Principal
Since automated creation is restricted by organizational policies, you need to create a service principal manually:

1. Go to Azure Portal > Azure Active Directory > App registrations
2. Click "New registration"
3. Name: "TodoList-GitHubActions"
4. Register the application
5. Note down the Application (client) ID and Directory (tenant) ID

### Step 2: Create Client Secret
1. In the app registration, go to "Certificates & secrets"
2. Click "New client secret"
3. Add description: "GitHub Actions Secret"
4. Set expiration (recommended: 12 months)
5. Copy the secret value immediately

### Step 3: Assign Permissions
1. Go to Subscriptions > Your Subscription > Access control (IAM)
2. Click "Add role assignment"
3. Role: "Contributor"
4. Assign access to: "User, group, or service principal"
5. Select your TodoList-GitHubActions app
6. Click "Review + assign"

### Step 4: Configure GitHub Repository

#### GitHub Variables (Repository Settings > Secrets and variables > Actions > Variables)
```
AZURE_SUBSCRIPTION_ID = 31123a85-42f7-4b2c-a74f-3c580102fb48
AZURE_TENANT_ID = 16b3c013-d300-468d-ac64-7eda0820b6d3
AZURE_CLIENT_ID = [Your App Registration Client ID]
AZURE_LOCATION = eastus
```

#### GitHub Secrets (Repository Settings > Secrets and variables > Actions > Secrets)
```
POSTGRES_ADMIN_PASSWORD = [Strong password for PostgreSQL]
```

### Step 5: Create GitHub Environment
1. Go to Repository Settings > Environments
2. Click "New environment"
3. Name: "dev"
4. Click "Configure environment"
5. Add the following environment variables:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID` 
   - `AZURE_SUBSCRIPTION_ID`

### Step 6: Configure Federated Credentials (Recommended)
For secure authentication without storing secrets:

1. In your App Registration, go to "Certificates & secrets"
2. Click "Federated credentials" tab
3. Click "Add credential"
4. Select "GitHub Actions deploying Azure resources"
5. Fill in:
   - Organization: pakbaz
   - Repository: TodoList
   - Entity type: Environment
   - Environment name: dev
6. Name: "github-federated"
7. Click "Add"

## Current Infrastructure

### Azure Resources Deployed
- **Container Registry**: For storing Docker images
- **Container Apps Environment**: For hosting the application
- **PostgreSQL Flexible Server**: Database backend
- **Key Vault**: Secure secrets management
- **Log Analytics**: Monitoring and logging
- **Application Insights**: Application performance monitoring

### Networking & Security
- All resources use managed identities for secure access
- PostgreSQL requires SSL connections
- Container Apps Environment integrates with Key Vault
- CORS is properly configured for MCP API access

## Deployment Process

Once authentication is configured:

1. **Automatic Trigger**: Push to `main` branch triggers deployment
2. **Manual Trigger**: Use GitHub Actions "Deploy to Azure" workflow
3. **Infrastructure**: Bicep templates create/update Azure resources
4. **Application**: Docker image is built and deployed to Container Apps

## Testing Deployment

After successful deployment, test these endpoints:
- **Health Check**: `https://[app-url]/health`
- **Web UI**: `https://[app-url]/`
- **MCP API**: `https://[app-url]/mcp/todos`

## Troubleshooting

### Common Issues
1. **Authentication Errors**: Verify service principal has correct permissions
2. **Resource Naming**: Check that resource names don't conflict
3. **Quota Limits**: Ensure subscription has sufficient quota
4. **PostgreSQL**: Verify admin password meets complexity requirements

### Checking Deployment Status
```bash
# View recent deployments
gh run list --limit 5

# Watch specific deployment
gh run watch [run-id]

# View deployment logs
gh run view [run-id] --log
```

## Security Best Practices

✅ **Implemented**:
- Managed Identity for inter-service communication
- Key Vault for secret management
- SSL/TLS for all connections
- Principle of least privilege for service accounts

✅ **Infrastructure as Code**:
- All resources defined in Bicep
- Version controlled and reviewable
- Consistent deployments across environments

✅ **Monitoring**:
- Application Insights for APM
- Log Analytics for centralized logging
- Health checks for application monitoring
