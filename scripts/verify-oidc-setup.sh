#!/bin/bash

# OIDC Setup Verification Script
# This script verifies that the Azure AD application and federated credentials are properly configured

set -e

APP_NAME="TodoList-GitHub-Actions-OIDC"
GITHUB_ORG="pakbaz"
GITHUB_REPO="TodoList"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

echo "🔍 Verifying GitHub OIDC Setup for Azure"
echo "=========================================="

# Check if logged into Azure
if ! az account show > /dev/null 2>&1; then
    print_error "Not logged into Azure. Run 'az login' first."
    exit 1
fi

print_status "Azure CLI authentication verified"

# Get application details
echo -e "\n📱 Application Registration:"
APP_DETAILS=$(az ad app list --display-name "$APP_NAME" --query "[0]" 2>/dev/null)

if [ "$APP_DETAILS" = "null" ] || [ -z "$APP_DETAILS" ]; then
    print_error "Application '$APP_NAME' not found"
    exit 1
fi

APP_ID=$(echo "$APP_DETAILS" | jq -r '.appId')
OBJECT_ID=$(echo "$APP_DETAILS" | jq -r '.id')

print_status "Application found: $APP_ID"

# Check service principal
echo -e "\n👤 Service Principal:"
SP_DETAILS=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0]" 2>/dev/null)

if [ "$SP_DETAILS" = "null" ] || [ -z "$SP_DETAILS" ]; then
    print_error "Service principal not found for application"
    exit 1
fi

SP_ID=$(echo "$SP_DETAILS" | jq -r '.id')
print_status "Service principal found: $SP_ID"

# Check role assignments
echo -e "\n🔐 Role Assignments:"
ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$APP_ID" --query "[?roleDefinitionName=='Contributor']" 2>/dev/null)

if [ "$(echo "$ROLE_ASSIGNMENTS" | jq length)" -gt 0 ]; then
    SCOPE=$(echo "$ROLE_ASSIGNMENTS" | jq -r '.[0].scope')
    print_status "Contributor role assigned to: $SCOPE"
else
    print_warning "No Contributor role assignments found"
fi

# Check federated credentials
echo -e "\n🔗 Federated Credentials:"
FEDERATED_CREDS=$(az ad app federated-credential list --id "$OBJECT_ID" 2>/dev/null)

EXPECTED_CREDS=(
    "main-branch"
    "pull-requests"
    "dev-environment"
    "staging-environment"
    "production-environment"
)

for cred_name in "${EXPECTED_CREDS[@]}"; do
    if echo "$FEDERATED_CREDS" | jq -e ".[] | select(.name == \"$cred_name\")" > /dev/null; then
        SUBJECT=$(echo "$FEDERATED_CREDS" | jq -r ".[] | select(.name == \"$cred_name\") | .subject")
        print_status "$cred_name: $SUBJECT"
    else
        print_error "$cred_name: Not found"
    fi
done

# Summary
echo -e "\n📋 Configuration Summary:"
echo "=========================="
echo "Application ID: $APP_ID"
echo "Tenant ID: $(az account show --query tenantId -o tsv)"
echo "Subscription ID: $(az account show --query id -o tsv)"

echo -e "\n🚀 GitHub Repository Setup:"
echo "=============================="
echo "1. Go to: https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions"
echo "2. Add these secrets:"
echo "   - AZURE_CLIENT_ID: $APP_ID"
echo "   - AZURE_TENANT_ID: $(az account show --query tenantId -o tsv)"
echo "   - AZURE_SUBSCRIPTION_ID: $(az account show --query id -o tsv)"
echo "   - POSTGRES_ADMIN_PASSWORD: [your-secure-password]"

echo -e "\n✨ OIDC setup verification completed!"
