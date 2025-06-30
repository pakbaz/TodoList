#!/usr/bin/env bash

# Azure OIDC Setup Script for GitHub Actions
# This script sets up Azure AD Application and Federated Identity for secure GitHub Actions deployment

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables - EDIT THESE
GITHUB_ORG="your-github-org"
GITHUB_REPO="your-repo-name"
AZURE_LOCATION="eastus"
ENVIRONMENT_NAME="dev"

echo -e "${BLUE}🚀 Azure OIDC Setup for TodoList Application${NC}"
echo "=================================================="

# Check if user is logged in to Azure
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Please login to Azure first: az login${NC}"
    exit 1
fi

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
SUBSCRIPTION_NAME=$(az account show --query name --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)

echo -e "${GREEN}✅ Azure Subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})${NC}"
echo -e "${GREEN}✅ Tenant ID: ${TENANT_ID}${NC}"

# Generate resource names
RESOURCE_GROUP="rg-todolist-${ENVIRONMENT_NAME}"
APP_NAME="GithubOIDC-TodoList-${ENVIRONMENT_NAME}"

echo ""
echo -e "${YELLOW}📋 Configuration:${NC}"
echo "   Resource Group: ${RESOURCE_GROUP}"
echo "   Location: ${AZURE_LOCATION}"
echo "   GitHub: ${GITHUB_ORG}/${GITHUB_REPO}"
echo "   Environment: ${ENVIRONMENT_NAME}"
echo "   App Name: ${APP_NAME}"
echo ""

read -p "Continue with this configuration? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo -e "${BLUE}📁 Creating Resource Group...${NC}"
az group create --name "${RESOURCE_GROUP}" --location "${AZURE_LOCATION}" --tags "Environment=${ENVIRONMENT_NAME}" "Application=TodoList" "ManagedBy=GitHubActions"

echo -e "${BLUE}🔐 Creating Azure AD Application...${NC}"

# Create Azure AD application
APP_ID=$(az ad app create \
    --display-name "${APP_NAME}" \
    --query appId \
    --output tsv)

echo -e "${GREEN}✅ Created Azure AD App: ${APP_ID}${NC}"

# Create service principal
az ad sp create --id "${APP_ID}" --query objectId --output tsv

echo -e "${GREEN}✅ Created Service Principal${NC}"

# Assign Contributor role to the service principal on the resource group
az role assignment create \
    --assignee "${APP_ID}" \
    --role "Contributor" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

echo -e "${GREEN}✅ Assigned Contributor role${NC}"

# Create federated credential for main branch
echo -e "${BLUE}🔗 Creating Federated Credentials...${NC}"

# Main branch credential
az ad app federated-credential create \
    --id "${APP_ID}" \
    --parameters '{
        "name": "github-main",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "repo:'${GITHUB_ORG}'/'${GITHUB_REPO}':ref:refs/heads/main",
        "description": "GitHub Actions - Main Branch",
        "audiences": ["api://AzureADTokenExchange"]
    }'

# Pull request credential
az ad app federated-credential create \
    --id "${APP_ID}" \
    --parameters '{
        "name": "github-pr",
        "issuer": "https://token.actions.githubusercontent.com", 
        "subject": "repo:'${GITHUB_ORG}'/'${GITHUB_REPO}':pull_request",
        "description": "GitHub Actions - Pull Requests",
        "audiences": ["api://AzureADTokenExchange"]
    }'

# Environment-specific credential (if not dev)
if [ "${ENVIRONMENT_NAME}" != "dev" ]; then
    az ad app federated-credential create \
        --id "${APP_ID}" \
        --parameters '{
            "name": "github-env-'${ENVIRONMENT_NAME}'",
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "repo:'${GITHUB_ORG}'/'${GITHUB_REPO}':environment:'${ENVIRONMENT_NAME}'",
            "description": "GitHub Actions - '${ENVIRONMENT_NAME}' Environment",
            "audiences": ["api://AzureADTokenExchange"]
        }'
fi

echo -e "${GREEN}✅ Created Federated Credentials${NC}"

echo ""
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo "=================================================="
echo ""
echo -e "${YELLOW}📋 GitHub Repository Variables (Settings > Secrets and variables > Actions > Variables):${NC}"
echo ""
echo "AZURE_CLIENT_ID: ${APP_ID}"
echo "AZURE_TENANT_ID: ${TENANT_ID}"
echo "AZURE_SUBSCRIPTION_ID: ${SUBSCRIPTION_ID}"
echo "AZURE_LOCATION: ${AZURE_LOCATION}"
echo ""
echo -e "${YELLOW}🛡️ GitHub Environment Protection:${NC}"
echo "1. Go to Settings > Environments"
echo "2. Create environment: ${ENVIRONMENT_NAME}"
echo "3. Add required reviewers if desired"
echo "4. Add environment-specific variables if needed"
echo ""
echo -e "${YELLOW}🚀 Ready to Deploy:${NC}"
echo "1. Push your code to the main branch"
echo "2. GitHub Actions will automatically deploy to Azure"
echo "3. Monitor the deployment in the Actions tab"
echo ""
echo -e "${BLUE}💡 Next Steps:${NC}"
echo "- Review and adjust the Bicep templates in infra/"
echo "- Customize the GitHub Actions workflows in .github/workflows/"
echo "- Test the deployment with: gh workflow run \"Deploy to Azure\""
echo ""
echo -e "${GREEN}✅ All done! Happy deploying! 🚀${NC}"
