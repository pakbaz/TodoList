# TodoList Deployment Guide

## Prerequisites

Before deploying the TodoList application to Azure, ensure you have the following:

1. **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Terraform** - [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) (v1.0+)
3. **Docker** - [Install Docker](https://docs.docker.com/get-docker/) (for local testing)
4. **Azure Subscription** - An active Azure subscription with contributor permissions
5. **Git** - For version control and CI/CD setup

## Step 1: Initial Setup

### 1.1 Clone the Repository

```bash
git clone <your-repository-url>
cd TodoList
```

### 1.2 Azure Login

```bash
az login
```

Verify your subscription:
```bash
az account show
```

If you have multiple subscriptions, set the correct one:
```bash
az account set --subscription "your-subscription-id"
```

## Step 2: Infrastructure Deployment

### 2.1 Set Up Terraform Backend (Optional but Recommended)

For production deployments, use remote state storage:

**Windows (PowerShell):**
```powershell
cd infra
.\setup-backend.ps1
```

**Linux/macOS:**
```bash
cd infra
chmod +x setup-backend.sh
./setup-backend.sh
```

This script will:
- Create a resource group for Terraform state
- Create a storage account and container
- Generate backend configuration files

### 2.2 Configure Terraform Variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your preferred settings:

```hcl
# Basic Configuration
environment = "prod"
location    = "East US"
project_name = "todolist"

# PostgreSQL Configuration
postgresql_sku_name = "B_Standard_B1ms"  # Start with basic tier
postgresql_storage_mb = 32768             # 32 GB
postgresql_version = "15"

# Container Apps Configuration
container_app_min_replicas = 1
container_app_max_replicas = 5
container_cpu = "0.5"
container_memory = "1Gi"

# Security Settings
enable_https_only = true
enable_managed_identity = true

# Tags for cost tracking
tags = {
  Project = "TodoList"
  Environment = "Production"
  Owner = "Your Team Name"
}
```

### 2.3 Initialize and Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Optional: If using remote backend
terraform init -backend-config=backend-config.txt

# Validate configuration
terraform validate

# Plan the deployment
terraform plan -var-file="terraform.tfvars"

# Apply the infrastructure (this will create Azure resources)
terraform apply -var-file="terraform.tfvars"
```

**⚠️ Important:** The `terraform apply` command will create billable Azure resources. Review the plan carefully before proceeding.

## Step 3: Application Deployment

### 3.1 Build and Push Container Image

After infrastructure is created, you need to build and push the application container:

```bash
# Get ACR login server from Terraform output
ACR_NAME=$(terraform output -raw container_registry_name)
ACR_SERVER=$(terraform output -raw container_registry_login_server)

# Login to Azure Container Registry
az acr login --name $ACR_NAME

# Build and push the container image
cd ..  # Go back to project root
docker build -t $ACR_SERVER/todolist:latest .
docker push $ACR_SERVER/todolist:latest
```

### 3.2 Update Container App

```bash
# Get resource information from Terraform
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
CONTAINER_APP=$(terraform output -raw container_app_name)

# Update the container app with the new image
az containerapp update \
  --name $CONTAINER_APP \
  --resource-group $RESOURCE_GROUP \
  --image $ACR_SERVER/todolist:latest
```

### 3.3 Verify Deployment

```bash
# Get the application URL
APP_URL=$(terraform output -raw container_app_url)
echo "Application URL: $APP_URL"

# Test the application
curl "$APP_URL/health"
```

## Step 4: CI/CD Setup (Recommended)

### 4.1 Create GitHub Secrets

Add the following secrets to your GitHub repository (Settings > Secrets and Variables > Actions):

```bash
# Create a service principal for GitHub Actions
az ad sp create-for-rbac \
  --name "sp-todolist-github" \
  --role contributor \
  --scopes /subscriptions/<your-subscription-id> \
  --sdk-auth
```

Add these secrets to GitHub:
- `AZURE_CREDENTIALS`: Output from the service principal creation
- `TERRAFORM_STATE_RESOURCE_GROUP`: From backend setup
- `TERRAFORM_STATE_STORAGE_ACCOUNT`: From backend setup  
- `TERRAFORM_STATE_CONTAINER`: From backend setup

### 4.2 Configure Repository Variables

Set these repository variables in GitHub:
- `AZURE_RESOURCE_GROUP`: Your resource group name
- `CONTAINER_REGISTRY`: Your ACR name
- `CONTAINER_APP_NAME`: Your container app name

### 4.3 Enable GitHub Actions

The CI/CD pipeline is automatically configured in `.github/workflows/deploy.yml`. It will:
- Build and test the application on every push
- Deploy to Azure on pushes to the main branch
- Run security scans and health checks

## Step 5: Database Setup

### 5.1 Connect to PostgreSQL

```bash
# Get connection details from Terraform outputs
POSTGRESQL_SERVER=$(terraform output -raw postgresql_server_name)
POSTGRESQL_ADMIN=$(terraform output -raw postgresql_admin_username)

# Connect to PostgreSQL
az postgres flexible-server connect \
  --name $POSTGRESQL_SERVER \
  --admin-user $POSTGRESQL_ADMIN \
  --database todolistdb
```

### 5.2 Create Application User (Optional)

For better security, create a dedicated application user:

```sql
-- Connect as admin and run these commands
CREATE USER app_user WITH PASSWORD 'your-secure-password';
GRANT CONNECT ON DATABASE todolistdb TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_user;
```

## Step 6: Monitoring and Maintenance

### 6.1 Application Insights

Monitor your application using Azure Application Insights:

```bash
# Get Application Insights details
APP_INSIGHTS=$(terraform output -raw application_insights_name)
echo "Application Insights: $APP_INSIGHTS"
```

### 6.2 Log Analytics

View container logs:

```bash
# View recent logs
az containerapp logs show \
  --name $CONTAINER_APP \
  --resource-group $RESOURCE_GROUP \
  --follow
```

### 6.3 Health Monitoring

Set up alerts for:
- High CPU/Memory usage
- Database connection issues
- Application errors
- Response time degradation

## Troubleshooting

### Common Issues

1. **Container App Won't Start**
   ```bash
   # Check logs
   az containerapp logs show --name $CONTAINER_APP --resource-group $RESOURCE_GROUP
   
   # Check revisions
   az containerapp revision list --name $CONTAINER_APP --resource-group $RESOURCE_GROUP
   ```

2. **Database Connection Issues**
   ```bash
   # Check firewall rules
   az postgres flexible-server firewall-rule list \
     --name $POSTGRESQL_SERVER \
     --resource-group $RESOURCE_GROUP
   
   # Test connectivity
   az postgres flexible-server connect \
     --name $POSTGRESQL_SERVER \
     --admin-user $POSTGRESQL_ADMIN
   ```

3. **Container Registry Access Issues**
   ```bash
   # Re-login to ACR
   az acr login --name $ACR_NAME
   
   # Check permissions
   az acr repository list --name $ACR_NAME
   ```

### Getting Help

- Check the [Azure Container Apps documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- Review [PostgreSQL Flexible Server docs](https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/)
- Visit the [Terraform Azure Provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## Cost Management

### Monitor Costs

```bash
# View current month costs
az consumption usage list --include-additional-properties --include-meter-details

# Set up cost alerts
az consumption budget create \
  --budget-name "todolist-monthly-budget" \
  --amount 100 \
  --time-grain Monthly
```

### Cost Optimization Tips

1. **Use Burstable PostgreSQL tier** for development/testing
2. **Scale down Container Apps** during off-hours
3. **Set up auto-scaling rules** based on CPU/memory
4. **Use Basic Container Registry** unless you need advanced features
5. **Set log retention policies** to manage storage costs

## Cleanup

To remove all Azure resources and avoid charges:

```bash
cd infra
terraform destroy -var-file="terraform.tfvars"
```

**⚠️ Warning:** This will permanently delete all data and resources. Make sure to backup any important data first.

## Next Steps

1. **Custom Domain**: Configure a custom domain for your application
2. **SSL Certificates**: Set up automated SSL certificate management
3. **Backup Strategy**: Implement database backup and disaster recovery
4. **Performance Optimization**: Configure CDN and caching
5. **Security Hardening**: Implement additional security measures
6. **Monitoring**: Set up comprehensive monitoring and alerting

For more advanced configurations and production hardening, refer to the detailed documentation in the `infra/README.md` file.
