#!/bin/bash

# GitHub OIDC Setup for Azure
# This script creates an Azure AD application registration with federated credentials for GitHub Actions
# Uses OpenID Connect (OIDC) for secure authentication without secrets

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to display usage
usage() {
    echo "Usage: $0 -o <github-org> -r <github-repo> [-s <subscription-id>] [-a <app-name>]"
    echo "  -o, --org          GitHub organization name"
    echo "  -r, --repo         GitHub repository name"
    echo "  -s, --subscription Azure subscription ID (optional, uses current if not provided)"
    echo "  -a, --app-name     Application name (optional, default: TodoList-GitHub-Actions-OIDC)"
    echo "  -h, --help         Display this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--org)
            GITHUB_ORG="$2"
            shift 2
            ;;
        -r|--repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        -s|--subscription)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -a|--app-name)
            APP_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$GITHUB_ORG" ]] || [[ -z "$GITHUB_REPO" ]]; then
    echo "Error: GitHub organization and repository are required"
    usage
fi

# Set default app name if not provided
APP_NAME="${APP_NAME:-TodoList-GitHub-Actions-OIDC}"

print_color $GREEN "🚀 Setting up GitHub OIDC with Azure Entra ID"
print_color $YELLOW "Organization: $GITHUB_ORG"
print_color $YELLOW "Repository: $GITHUB_REPO"

# Get current subscription and tenant if not provided
if [[ -z "$SUBSCRIPTION_ID" ]]; then
    SUBSCRIPTION_ID=$(az account show --query id --output tsv)
    print_color $YELLOW "Using current subscription: $SUBSCRIPTION_ID"
fi

TENANT_ID=$(az account show --query tenantId --output tsv)
print_color $YELLOW "Tenant ID: $TENANT_ID"

# Set the subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Check if application already exists
print_color $YELLOW "📋 Checking if application '$APP_NAME' already exists..."
EXISTING_APP=$(az ad app list --display-name "$APP_NAME" --query "[0]" 2>/dev/null || echo "null")

if [[ "$EXISTING_APP" != "null" ]]; then
    APP_ID=$(echo "$EXISTING_APP" | jq -r '.appId')
    OBJECT_ID=$(echo "$EXISTING_APP" | jq -r '.id')
    print_color $YELLOW "Application already exists with ID: $APP_ID"
else
    # Create Azure AD Application Registration
    print_color $YELLOW "📱 Creating Azure AD Application Registration..."
    APP_RESULT=$(az ad app create --display-name "$APP_NAME" --query "{appId:appId,id:id}")
    APP_ID=$(echo "$APP_RESULT" | jq -r '.appId')
    OBJECT_ID=$(echo "$APP_RESULT" | jq -r '.id')
    print_color $GREEN "✅ Created application with ID: $APP_ID"
fi

# Create Service Principal
print_color $YELLOW "👤 Creating Service Principal..."
SP_EXISTS=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" --output tsv 2>/dev/null || echo "")
if [[ -z "$SP_EXISTS" ]]; then
    SP_ID=$(az ad sp create --id "$APP_ID" --query "id" --output tsv)
    print_color $GREEN "✅ Created service principal: $SP_ID"
else
    print_color $YELLOW "Service principal already exists: $SP_EXISTS"
    SP_ID="$SP_EXISTS"
fi

# Assign Contributor role to the subscription
print_color $YELLOW "🔐 Assigning Contributor role..."
if az role assignment create --assignee "$APP_ID" --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null 2>&1; then
    print_color $GREEN "✅ Assigned Contributor role"
else
    print_color $YELLOW "Role assignment may already exist"
fi

# Create federated credentials for different GitHub environments
print_color $YELLOW "🔗 Creating federated credentials..."

declare -a credentials=(
    "main-branch|repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/main|Main branch deployments"
    "pull-requests|repo:$GITHUB_ORG/$GITHUB_REPO:pull_request|Pull request builds"
    "dev-environment|repo:$GITHUB_ORG/$GITHUB_REPO:environment:dev|Dev environment deployments"
    "staging-environment|repo:$GITHUB_ORG/$GITHUB_REPO:environment:staging|Staging environment deployments"
    "production-environment|repo:$GITHUB_ORG/$GITHUB_REPO:environment:production|Production environment deployments"
)

for cred_info in "${credentials[@]}"; do
    IFS='|' read -r name subject description <<< "$cred_info"
    print_color $YELLOW "Creating credential: $name"
    
    # Check if credential already exists
    EXISTING_CRED=$(az ad app federated-credential list --id "$OBJECT_ID" --query "[?name=='$name']" 2>/dev/null || echo "[]")
    
    if [[ "$(echo "$EXISTING_CRED" | jq length)" -eq 0 ]]; then
        # Create the credential
        cat <<EOF | az ad app federated-credential create --id "$OBJECT_ID" --parameters "@-" >/dev/null
{
    "name": "$name",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "$subject",
    "description": "$description",
    "audiences": ["api://AzureADTokenExchange"]
}
EOF
        print_color $GREEN "  ✅ Created: $name"
    else
        print_color $YELLOW "  ⚠️  Already exists: $name"
    fi
done

# Output GitHub Actions secrets/variables
print_color $GREEN "\n🎯 GitHub Repository Configuration"
print_color $GREEN "================================================"
print_color $YELLOW "Add these secrets to your GitHub repository:"
print_color $YELLOW "($GITHUB_ORG/$GITHUB_REPO -> Settings -> Secrets and variables -> Actions)"
echo ""

echo -n "AZURE_CLIENT_ID: "
print_color $GREEN "$APP_ID"

echo -n "AZURE_TENANT_ID: "
print_color $GREEN "$TENANT_ID"

echo -n "AZURE_SUBSCRIPTION_ID: "
print_color $GREEN "$SUBSCRIPTION_ID"

echo ""
print_color $NC "Repository Variables (optional but recommended):"
echo -n "AZURE_RESOURCE_GROUP: "
print_color $GREEN "rg-todolist-dev"

echo -n "AZURE_LOCATION: "
print_color $GREEN "eastus"

# Create a summary file
SUMMARY_FILE="azure-github-oidc-setup.json"
cat > "$SUMMARY_FILE" <<EOF
{
    "appName": "$APP_NAME",
    "appId": "$APP_ID",
    "tenantId": "$TENANT_ID",
    "subscriptionId": "$SUBSCRIPTION_ID",
    "gitHubOrg": "$GITHUB_ORG",
    "gitHubRepo": "$GITHUB_REPO",
    "createdAt": "$(date '+%Y-%m-%d %H:%M:%S')",
    "secrets": {
        "AZURE_CLIENT_ID": "$APP_ID",
        "AZURE_TENANT_ID": "$TENANT_ID",
        "AZURE_SUBSCRIPTION_ID": "$SUBSCRIPTION_ID"
    },
    "variables": {
        "AZURE_RESOURCE_GROUP": "rg-todolist-dev",
        "AZURE_LOCATION": "eastus"
    }
}
EOF

print_color $GREEN "\n📄 Configuration saved to: $SUMMARY_FILE"

print_color $GREEN "\n🔧 Next Steps:"
print_color $NC "1. Add the secrets above to your GitHub repository"
print_color $NC "2. Update your GitHub Actions workflow to use OIDC authentication"
print_color $NC "3. Test the deployment pipeline"

print_color $GREEN "\n✨ Setup completed successfully!"
