# Terraform Backend State Setup Script
# Run this script before using Terraform to set up remote state storage

# Variables
$resourceGroupName = "rg-terraform-state"
$storageAccountName = "satodolisttfstate$(Get-Random -Minimum 1000 -Maximum 9999)"
$containerName = "tfstate"
$location = "East US"

Write-Host "🚀 Setting up Terraform backend state storage..." -ForegroundColor Green

# Login to Azure (if not already logged in)
try {
    $context = az account show --query "name" -o tsv
    Write-Host "✅ Already logged in to Azure: $context" -ForegroundColor Green
} catch {
    Write-Host "🔐 Please log in to Azure..." -ForegroundColor Yellow
    az login
}

# Create resource group for Terraform state
Write-Host "📁 Creating resource group: $resourceGroupName" -ForegroundColor Cyan
az group create --name $resourceGroupName --location $location

# Create storage account
Write-Host "💾 Creating storage account: $storageAccountName" -ForegroundColor Cyan
az storage account create `
    --resource-group $resourceGroupName `
    --name $storageAccountName `
    --sku Standard_LRS `
    --encryption-services blob `
    --https-only true `
    --kind StorageV2 `
    --access-tier Hot

# Get storage account key
$accountKey = az storage account keys list `
    --resource-group $resourceGroupName `
    --account-name $storageAccountName `
    --query "[0].value" -o tsv

# Create blob container
Write-Host "📦 Creating blob container: $containerName" -ForegroundColor Cyan
az storage container create `
    --name $containerName `
    --account-name $storageAccountName `
    --account-key $accountKey

Write-Host "✅ Terraform backend setup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Backend Configuration:" -ForegroundColor Yellow
Write-Host "Resource Group: $resourceGroupName"
Write-Host "Storage Account: $storageAccountName"
Write-Host "Container: $containerName"
Write-Host ""

# Create backend config file
$backendConfig = @"
# Terraform Backend Configuration
# Use these values when initializing Terraform

resource_group_name  = "$resourceGroupName"
storage_account_name = "$storageAccountName"
container_name       = "$containerName"
key                  = "todolist.terraform.tfstate"
"@

$backendConfig | Out-File -FilePath "backend-config.txt" -Encoding UTF8
Write-Host "💾 Backend configuration saved to: backend-config.txt" -ForegroundColor Green

Write-Host ""
Write-Host "🔧 Next steps:" -ForegroundColor Yellow
Write-Host "1. Copy terraform.tfvars.example to terraform.tfvars"
Write-Host "2. Edit terraform.tfvars with your desired values"
Write-Host "3. Run: terraform init -backend-config=backend-config.txt"
Write-Host "4. Run: terraform plan"
Write-Host "5. Run: terraform apply"
Write-Host ""

# Save GitHub Secrets information
$secretsInfo = @"
# GitHub Secrets Configuration
# Add these secrets to your GitHub repository:

TERRAFORM_STATE_RESOURCE_GROUP: $resourceGroupName
TERRAFORM_STATE_STORAGE_ACCOUNT: $storageAccountName
TERRAFORM_STATE_CONTAINER: $containerName

# Create a service principal for GitHub Actions:
# az ad sp create-for-rbac --name "sp-todolist-github" --role contributor --scopes /subscriptions/<subscription-id> --sdk-auth

# Add the output as AZURE_CREDENTIALS secret in GitHub
"@

$secretsInfo | Out-File -FilePath "github-secrets-info.txt" -Encoding UTF8
Write-Host "🔐 GitHub secrets information saved to: github-secrets-info.txt" -ForegroundColor Green
