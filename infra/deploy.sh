#!/bin/bash

# TodoList Infrastructure Deployment Script
# This script deploys the TodoList infrastructure to Azure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BICEP_TEMPLATE="$SCRIPT_DIR/main.bicep"
DEFAULT_LOCATION="East US 2"
APPLICATION_NAME="todolist"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check Bicep
    if ! az bicep version &> /dev/null; then
        print_warning "Bicep is not installed. Installing..."
        az bicep install
    fi
    
    print_success "Prerequisites check completed"
}

# Function to validate Bicep template
validate_template() {
    print_status "Validating Bicep template..."
    
    if ! az bicep build --file "$BICEP_TEMPLATE" --stdout > /dev/null; then
        print_error "Bicep template validation failed"
        exit 1
    fi
    
    print_success "Bicep template validation completed"
}

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to display help
show_help() {
    cat << EOF
TodoList Infrastructure Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    -e, --environment ENVIRONMENT    Environment to deploy (dev, staging, prod)
    -l, --location LOCATION         Azure region (default: $DEFAULT_LOCATION)
    -r, --resource-group GROUP      Resource group name (default: rg-todolist-ENVIRONMENT)
    -p, --password PASSWORD         PostgreSQL admin password (default: auto-generated)
    -s, --subscription ID           Azure subscription ID
    -v, --validate-only             Only validate, don't deploy
    -h, --help                      Show this help message

Examples:
    $0 -e dev                       Deploy to dev environment
    $0 -e prod -l "West US 2"       Deploy to prod in West US 2
    $0 -e staging --validate-only   Validate staging deployment

EOF
}

# Parse command line arguments
ENVIRONMENT=""
LOCATION="$DEFAULT_LOCATION"
RESOURCE_GROUP=""
PASSWORD=""
SUBSCRIPTION=""
VALIDATE_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -r|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -s|--subscription)
            SUBSCRIPTION="$2"
            shift 2
            ;;
        -v|--validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$ENVIRONMENT" ]]; then
    print_error "Environment is required. Use -e or --environment."
    show_help
    exit 1
fi

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "prod" ]]; then
    print_error "Environment must be one of: dev, staging, prod"
    exit 1
fi

# Set defaults
if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="rg-$APPLICATION_NAME-$ENVIRONMENT"
fi

if [[ -z "$PASSWORD" ]]; then
    PASSWORD=$(generate_password)
    print_warning "Auto-generated PostgreSQL password. Please save it securely."
fi

# Set subscription if provided
if [[ -n "$SUBSCRIPTION" ]]; then
    print_status "Setting Azure subscription to $SUBSCRIPTION"
    az account set --subscription "$SUBSCRIPTION"
fi

# Display configuration
print_status "Deployment Configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  Location: $LOCATION"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Subscription: $(az account show --query id -o tsv)"

# Check prerequisites
check_prerequisites

# Validate template
validate_template

# Create resource group
print_status "Creating resource group $RESOURCE_GROUP..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags Environment="$ENVIRONMENT" Application="$APPLICATION_NAME" \
    --output none

print_success "Resource group created successfully"

# Validate deployment
print_status "Validating deployment..."
VALIDATION_RESULT=$(az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$BICEP_TEMPLATE" \
    --parameters environment="$ENVIRONMENT" \
    --parameters postgresAdminPassword="$PASSWORD" \
    --output json)

if [[ $? -ne 0 ]]; then
    print_error "Deployment validation failed"
    echo "$VALIDATION_RESULT"
    exit 1
fi

print_success "Deployment validation completed"

# Exit if validate-only
if [[ "$VALIDATE_ONLY" == true ]]; then
    print_success "Validation completed successfully. Exiting without deployment."
    exit 0
fi

# Deploy infrastructure
print_status "Deploying infrastructure..."
DEPLOYMENT_NAME="todolist-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S)"

DEPLOYMENT_RESULT=$(az deployment group create \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$BICEP_TEMPLATE" \
    --parameters environment="$ENVIRONMENT" \
    --parameters postgresAdminPassword="$PASSWORD" \
    --output json)

if [[ $? -ne 0 ]]; then
    print_error "Deployment failed"
    echo "$DEPLOYMENT_RESULT"
    exit 1
fi

# Extract outputs
CONTAINER_APP_URL=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.containerAppUrl.value // empty')
REGISTRY_LOGIN_SERVER=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.containerRegistryLoginServer.value // empty')
KEY_VAULT_NAME=$(echo "$DEPLOYMENT_RESULT" | jq -r '.properties.outputs.keyVaultName.value // empty')

print_success "Infrastructure deployment completed successfully!"

# Display results
cat << EOF

=== Deployment Results ===
Environment: $ENVIRONMENT
Resource Group: $RESOURCE_GROUP
Deployment Name: $DEPLOYMENT_NAME

Key Resources:
- Container App URL: ${CONTAINER_APP_URL:-"Not available"}
- Container Registry: ${REGISTRY_LOGIN_SERVER:-"Not available"}
- Key Vault: ${KEY_VAULT_NAME:-"Not available"}

Next Steps:
1. Build and push your container image:
   docker build -t todolist:latest .
   az acr login --name $REGISTRY_LOGIN_SERVER
   docker tag todolist:latest $REGISTRY_LOGIN_SERVER/todolist:latest
   docker push $REGISTRY_LOGIN_SERVER/todolist:latest

2. Update the container app with your image:
   az containerapp update \\
     --name <container-app-name> \\
     --resource-group $RESOURCE_GROUP \\
     --image $REGISTRY_LOGIN_SERVER/todolist:latest

3. Access your application:
   ${CONTAINER_APP_URL:-"Check Azure portal for the URL"}

4. Monitor your application:
   az portal dashboard show --name "TodoList Dashboard" (once configured)

EOF

# Save deployment info
DEPLOYMENT_INFO_FILE="deployment-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S).json"
echo "$DEPLOYMENT_RESULT" > "$DEPLOYMENT_INFO_FILE"
print_success "Deployment details saved to $DEPLOYMENT_INFO_FILE"

print_success "Deployment script completed successfully!"
