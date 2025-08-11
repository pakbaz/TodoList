#!/bin/bash
# Terraform Backend State Setup Script (Linux/macOS)
# Run this script before using Terraform to set up remote state storage

# Variables
RESOURCE_GROUP_NAME="rg-terraform-state"
STORAGE_ACCOUNT_NAME="satodolisttfstate$((RANDOM % 9000 + 1000))"
CONTAINER_NAME="tfstate"
LOCATION="East US"

echo "🚀 Setting up Terraform backend state storage..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Login to Azure (if not already logged in)
if az account show &> /dev/null; then
    CONTEXT=$(az account show --query "name" -o tsv)
    echo "✅ Already logged in to Azure: $CONTEXT"
else
    echo "🔐 Please log in to Azure..."
    az login
fi

# Create resource group for Terraform state
echo "📁 Creating resource group: $RESOURCE_GROUP_NAME"
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"

# Create storage account
echo "💾 Creating storage account: $STORAGE_ACCOUNT_NAME"
az storage account create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --sku Standard_LRS \
    --encryption-services blob \
    --https-only true \
    --kind StorageV2 \
    --access-tier Hot

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --query "[0].value" -o tsv)

# Create blob container
echo "📦 Creating blob container: $CONTAINER_NAME"
az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$ACCOUNT_KEY"

echo "✅ Terraform backend setup completed!"
echo ""
echo "📋 Backend Configuration:"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Container: $CONTAINER_NAME"
echo ""

# Create backend config file
cat > backend-config.txt << EOF
# Terraform Backend Configuration
# Use these values when initializing Terraform

resource_group_name  = "$RESOURCE_GROUP_NAME"
storage_account_name = "$STORAGE_ACCOUNT_NAME"
container_name       = "$CONTAINER_NAME"
key                  = "todolist.terraform.tfstate"
EOF

echo "💾 Backend configuration saved to: backend-config.txt"

echo ""
echo "🔧 Next steps:"
echo "1. Copy terraform.tfvars.example to terraform.tfvars"
echo "2. Edit terraform.tfvars with your desired values"
echo "3. Run: terraform init -backend-config=backend-config.txt"
echo "4. Run: terraform plan"
echo "5. Run: terraform apply"
echo ""

# Save GitHub Secrets information
cat > github-secrets-info.txt << EOF
# GitHub Secrets Configuration
# Add these secrets to your GitHub repository:

TERRAFORM_STATE_RESOURCE_GROUP: $RESOURCE_GROUP_NAME
TERRAFORM_STATE_STORAGE_ACCOUNT: $STORAGE_ACCOUNT_NAME
TERRAFORM_STATE_CONTAINER: $CONTAINER_NAME

# Create a service principal for GitHub Actions:
# az ad sp create-for-rbac --name "sp-todolist-github" --role contributor --scopes /subscriptions/<subscription-id> --sdk-auth

# Add the output as AZURE_CREDENTIALS secret in GitHub
EOF

echo "🔐 GitHub secrets information saved to: github-secrets-info.txt"
