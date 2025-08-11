#!/bin/bash

# Manual Terraform Validation and Deployment Script
# Run this script to validate and deploy your infrastructure

set -e  # Exit on any error

echo "=== TodoList Azure Infrastructure Deployment ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Step 1: Check Prerequisites
echo -e "${YELLOW}Step 1: Checking Prerequisites...${NC}"
echo ""

echo -e "${CYAN}Checking Azure CLI...${NC}"
if command -v az &> /dev/null; then
    echo -e "${GREEN}✅ Azure CLI is installed${NC}"
    echo -e "${GRAY}Version: $(az version --output tsv --query '\"azure-cli\"')${NC}"
else
    echo -e "${RED}❌ Azure CLI not found. Please install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli${NC}"
    exit 1
fi

echo -e "${CYAN}Checking Terraform...${NC}"
if command -v terraform &> /dev/null; then
    echo -e "${GREEN}✅ Terraform is installed${NC}"
    echo -e "${GRAY}Version: $(terraform version | head -n1)${NC}"
else
    echo -e "${RED}❌ Terraform not found. Please install from: https://learn.hashicorp.com/tutorials/terraform/install-cli${NC}"
    exit 1
fi

echo -e "${CYAN}Checking Docker...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✅ Docker is installed${NC}"
    echo -e "${GRAY}Version: $(docker --version)${NC}"
else
    echo -e "${YELLOW}⚠️  Docker not found. You'll need it for container deployment.${NC}"
fi

echo ""

# Step 2: Azure Authentication
echo -e "${YELLOW}Step 2: Azure Authentication...${NC}"
echo ""

echo -e "${CYAN}Checking Azure authentication...${NC}"
if az account show &> /dev/null; then
    echo -e "${GREEN}✅ Already logged into Azure${NC}"
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)
    echo -e "${GRAY}Subscription: ${SUBSCRIPTION_NAME}${NC}"
    echo -e "${GRAY}Tenant: ${TENANT_ID}${NC}"
else
    echo -e "${RED}❌ Not logged into Azure. Please run:${NC}"
    echo "   az login"
    echo "   az account set --subscription 'your-subscription-id'"
    exit 1
fi

echo ""

# Step 3: Directory Setup
echo -e "${YELLOW}Step 3: Setting up working directory...${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INFRA_PATH="$PROJECT_ROOT/infra"

echo -e "${GRAY}Project root: ${PROJECT_ROOT}${NC}"
echo -e "${GRAY}Infrastructure path: ${INFRA_PATH}${NC}"

if [ ! -d "$INFRA_PATH" ]; then
    echo -e "${RED}❌ Infrastructure directory not found: ${INFRA_PATH}${NC}"
    exit 1
fi

cd "$INFRA_PATH"
echo -e "${GREEN}✅ Changed to infrastructure directory${NC}"
echo ""

# Step 4: Terraform Configuration
echo -e "${YELLOW}Step 4: Preparing Terraform configuration...${NC}"
echo ""

if [ ! -f "terraform.tfvars" ]; then
    if [ -f "terraform.tfvars.example" ]; then
        echo -e "${CYAN}Creating terraform.tfvars from example...${NC}"
        cp "terraform.tfvars.example" "terraform.tfvars"
        echo -e "${GREEN}✅ Created terraform.tfvars${NC}"
        echo -e "${YELLOW}⚠️  Please review and customize terraform.tfvars before proceeding!${NC}"
        echo ""
    else
        echo -e "${RED}❌ terraform.tfvars.example not found${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ terraform.tfvars already exists${NC}"
fi

echo ""

# Step 5: Terraform Initialization
echo -e "${YELLOW}Step 5: Initializing Terraform...${NC}"
echo ""

echo -e "${CYAN}Running terraform init...${NC}"
if terraform init; then
    echo -e "${GREEN}✅ Terraform initialized successfully${NC}"
else
    echo -e "${RED}❌ Terraform initialization failed${NC}"
    exit 1
fi

echo ""

# Step 6: Terraform Validation
echo -e "${YELLOW}Step 6: Validating Terraform configuration...${NC}"
echo ""

echo -e "${CYAN}Running terraform validate...${NC}"
if terraform validate; then
    echo -e "${GREEN}✅ Terraform configuration is valid${NC}"
else
    echo -e "${RED}❌ Terraform validation failed${NC}"
    echo ""
    echo -e "${YELLOW}Please fix the validation errors before proceeding.${NC}"
    exit 1
fi

echo ""

# Step 7: Terraform Format Check
echo -e "${YELLOW}Step 7: Checking Terraform formatting...${NC}"
echo ""

echo -e "${CYAN}Running terraform fmt...${NC}"
if terraform fmt -check -diff; then
    echo -e "${GREEN}✅ All files are properly formatted${NC}"
else
    echo -e "${YELLOW}⚠️  Some files need formatting. Auto-formatting...${NC}"
    terraform fmt
    echo -e "${GREEN}✅ Files have been formatted${NC}"
fi

echo ""

# Step 8: Terraform Plan
echo -e "${YELLOW}Step 8: Generating Terraform plan...${NC}"
echo ""

echo -e "${CYAN}This will show you what resources will be created...${NC}"
echo -e "${CYAN}Running terraform plan...${NC}"

PLAN_FILE="tfplan"
if terraform plan -out="$PLAN_FILE"; then
    echo -e "${GREEN}✅ Terraform plan generated successfully${NC}"
    echo ""
    echo -e "${GRAY}Plan saved to: ${PLAN_FILE}${NC}"
    echo ""
else
    echo -e "${RED}❌ Terraform plan failed${NC}"
    exit 1
fi

echo ""

# Step 9: Cost Estimation
echo -e "${YELLOW}Step 9: Cost Estimation...${NC}"
echo ""

echo -e "${CYAN}Estimated monthly costs (East US region):${NC}"
echo -e "${GRAY}• Container Apps (1-5 replicas): ~\$15-30/month${NC}"
echo -e "${GRAY}• PostgreSQL Flexible Server (B1ms): ~\$25-40/month${NC}"
echo -e "${GRAY}• Container Registry (Basic): ~\$5/month${NC}"
echo -e "${GRAY}• Application Insights: ~\$2-10/month${NC}"
echo -e "${GRAY}• Key Vault: ~\$1/month${NC}"
echo -e "${GRAY}• Log Analytics: ~\$2-5/month${NC}"
echo ""
echo -e "${YELLOW}Total estimated range: \$50-91/month${NC}"
echo ""

# Step 10: Deployment Decision
echo -e "${YELLOW}Step 10: Ready for deployment!${NC}"
echo ""

echo -e "${GREEN}✅ All pre-deployment checks passed!${NC}"
echo ""
echo -e "${CYAN}To deploy the infrastructure, run:${NC}"
echo "   terraform apply \"$PLAN_FILE\""
echo ""
echo -e "${CYAN}To deploy without the plan file:${NC}"
echo "   terraform apply"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will create billable Azure resources!${NC}"
echo ""

# Interactive deployment option
read -p "Do you want to deploy now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Deploying infrastructure...${NC}"
    echo ""
    
    if terraform apply "$PLAN_FILE"; then
        echo ""
        echo -e "${GREEN}🎉 Infrastructure deployed successfully!${NC}"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo "1. Build and push your container image"
        echo "2. Update the Container App with your image"
        echo "3. Test the application endpoints"
        echo ""
        echo -e "${GRAY}For detailed instructions, see DEPLOYMENT.md${NC}"
    else
        echo -e "${RED}❌ Deployment failed. Check the output above for details.${NC}"
        exit 1
    fi
else
    echo ""
    echo -e "${GRAY}Deployment skipped. You can deploy later using:${NC}"
    echo "   terraform apply \"$PLAN_FILE\""
    echo ""
    echo -e "${GRAY}Don't forget to clean up the plan file when done:${NC}"
    echo "   rm \"$PLAN_FILE\""
fi

echo ""
echo -e "${GREEN}=== Validation Complete ===${NC}"
