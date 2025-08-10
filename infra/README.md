# TodoList Azure Infrastructure (Terraform)

This folder contains Terraform IaC for deploying the TodoList Blazor Server (.NET 9) application onto Azure using a containerized architecture aligned with the "Azure Container Apps with managed PostgreSQL" reference pattern (derivable from Azure Architecture Center: serverless container apps + managed database + Key Vault + monitoring).

## ✅ Architecture Summary

Components provisioned:
- Resource Group
- Azure Container Registry (ACR) for images
- Log Analytics Workspace + Application Insights (for unified monitoring)
- Azure Key Vault for secrets (DB password, connection string)
- Azure Database for PostgreSQL Flexible Server (production-ready)
- Virtual Network with delegated subnets (Container Apps + PostgreSQL) for private networking (optional toggle)
- Container Apps Environment (ACA env)
- Container App (TodoList) referencing image in ACR
- Managed Identity (system-assigned) for Container App access to Key Vault & ACR (AcrPull)
- Role assignments (Key Vault secrets user / ACR pull / Monitoring metrics publisher)

Optional / toggles via variables:
- Public vs private Postgres access
- Enable autoscale customization
- Deploy staging slot (future extension placeholder)

## 🔐 Secrets Handling
- PostgreSQL admin password stored in Key Vault secret `postgres-admin-password`
- Application connection string stored in Key Vault secret `TodoList--ConnectionStrings--DefaultConnection`
- Container App uses Key Vault references (env vars) via managed identity (preview features may require enabling; fallback: inject secret values directly) – for simplicity in Terraform we map secrets into env vars at deploy time.

## 📂 Structure
```
infra/
  main.tf              # Root orchestration
  providers.tf         # Terraform / AzureRM provider setup
  variables.tf         # Input variables
  outputs.tf           # Key outputs
  backend.tf (optional placeholder for remote state)
  README.md            # (this file)
  modules/
    container_app/
      main.tf  variables.tf  outputs.tf
    postgres/
      main.tf  variables.tf  outputs.tf
    monitoring/
      main.tf  variables.tf  outputs.tf
```

## 🌍 Environments Strategy
Use workspaces (e.g., `terraform workspace new dev|staging|prod`) or separate state backends. Variables like `environment` prefix resource names. Scaling / SKU differs per environment (see variable defaults & maps).

## 🚀 Deployment Steps

### 1. Prerequisites
- Terraform CLI >= 1.7
- Azure CLI logged in: `az login`
- Sufficient permissions: Owner or least privileges (Resource Group + Role assignments)

### 2. Initialize
```powershell
cd infra
terraform init
```

### 3. (Optional) Select / Create Workspace
```powershell
terraform workspace list
terraform workspace new dev
terraform workspace select dev
```

### 4. Plan (What-If)
```powershell
terraform plan -var "environment=dev" -out tfplan
```

### 5. Apply
```powershell
terraform apply tfplan
```

### 6. Build & Push Image (if not using CI yet)
```powershell
$ACR_NAME=$(terraform output -raw acr_name)
az acr login --name $ACR_NAME
docker build -t $ACR_NAME.azurecr.io/todolist:dev ..
docker push $ACR_NAME.azurecr.io/todolist:dev
```

### 7. Update Container App Revision (if image changed manually)
```powershell
az containerapp update `
  --name $(terraform output -raw container_app_name) `
  --resource-group $(terraform output -raw resource_group_name) `
  --image $ACR_NAME.azurecr.io/todolist:dev
```

## 🔄 CI/CD (GitHub Actions)
A workflow (`.github/workflows/terraform-deploy.yml`) handles:
1. Checkout
2. Setup Terraform
3. Login to Azure via OIDC
4. Terraform init/plan/apply
5. Build & push image to ACR (only on changes to app or Dockerfile)
6. Update Container App with new image tag (Git SHA)

Additional workflows for quality assurance:
- `.github/workflows/build-test.yml` - Build, test, and Docker validation on PRs
- `.github/workflows/deploy.yml` - Full deployment with security scanning

### Security Scanning
Automated security scanning includes:
- **CodeQL Analysis** - Static application security testing (SAST)
- **Dependency Scanning** - Vulnerable package detection
- **.NET Security Audit** - Built-in vulnerability scanning
- **SARIF Upload** - Results integrated into GitHub Security tab

Required GitHub Actions Variables / Secrets:
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID` (federated credential for OIDC)
- `AZURE_RESOURCE_GROUP` (specific resource group name)
- `AZURE_LOCATION` (Azure region)
- `TF_VAR_postgres_admin_password` (secret) or supply via Key Vault after first deploy
- Optional: `ENVIRONMENT` for environment-specific configuration

## 🔧 Key Variables
| Name | Description | Default |
|------|-------------|---------|
| `environment` | Short environment name (dev/staging/prod) | dev |
| `location` | Azure region | eastus |
| `postgres_sku_name` | Flexible Server SKU | B_Standard_B1ms |
| `postgres_storage_mb` | Storage in MB | 32768 |
| `container_cpu` | vCPU for Container App | 0.5 |
| `container_memory` | Memory (Gi) | 1.0 |
| `acr_sku` | ACR SKU | Basic |
| `enable_vnet` | Whether to create VNet + delegated subnets | true |
| `autoscale_min_replicas` | Min replicas | 0 |
| `autoscale_max_replicas` | Max replicas | 5 |

## 📤 Outputs
- `resource_group_name`
- `acr_login_server`
- `container_app_url`
- `postgres_fqdn`

## 🧪 Smoke Test
After deploy:
```powershell
Invoke-RestMethod (terraform output -raw container_app_url)/health
```

## 🗑️ Destroy
```powershell
terraform destroy -var "environment=dev"
```

## 🛡️ Best Practices Applied
- Remote state placeholder (add backend config for prod)
- Separation via modules
- Naming convention: `<prefix>-<env>-<resourcetype>`
- Least privilege via managed identity & specific roles
- Autoscaling & logging included

## 📝 Future Enhancements
- Blue/Green or staging revision traffic splitting
- Private Endpoints for Postgres & Key Vault
- Key Vault secret reference injection instead of plain env vars
- Dapr sidecar for event-driven enhancements
