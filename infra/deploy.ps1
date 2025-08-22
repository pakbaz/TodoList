# TodoList Infrastructure Deployment Script (PowerShell)
# This script deploys the TodoList infrastructure to Azure

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,
    
    [string]$Location = 'East US 2',
    [string]$ResourceGroup = '',
    [string]$Password = '',
    [string]$Subscription = '',
    [switch]$ValidateOnly,
    [switch]$Help
)

# Configuration
$ApplicationName = 'todolist'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BicepTemplate = Join-Path $ScriptDir 'main.bicep'

# Function to display help
function Show-Help {
    Write-Host @"
TodoList Infrastructure Deployment Script (PowerShell)

Usage: .\deploy.ps1 [OPTIONS]

PARAMETERS:
    -Environment ENVIRONMENT        Environment to deploy (dev, staging, prod) [Required]
    -Location LOCATION             Azure region (default: East US 2)
    -ResourceGroup GROUP           Resource group name (default: rg-todolist-ENVIRONMENT)
    -Password PASSWORD             PostgreSQL admin password (default: auto-generated)
    -Subscription ID               Azure subscription ID
    -ValidateOnly                  Only validate, don't deploy
    -Help                          Show this help message

Examples:
    .\deploy.ps1 -Environment dev
    .\deploy.ps1 -Environment prod -Location "West US 2"
    .\deploy.ps1 -Environment staging -ValidateOnly

"@
}

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to generate secure password
function New-SecurePassword {
    $length = 25
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
    $password = -join ((1..$length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    # Check Azure CLI
    try {
        $null = Get-Command az -ErrorAction Stop
    }
    catch {
        Write-Error "Azure CLI is not installed. Please install it first."
        exit 1
    }
    
    # Check if logged in to Azure
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Not logged in"
        }
    }
    catch {
        Write-Error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    }
    
    # Check Bicep
    try {
        $null = az bicep version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Bicep is not installed. Installing..."
            az bicep install
        }
    }
    catch {
        Write-Warning "Bicep is not installed. Installing..."
        az bicep install
    }
    
    Write-Success "Prerequisites check completed"
}

# Function to validate Bicep template
function Test-BicepTemplate {
    Write-Status "Validating Bicep template..."
    
    $result = az bicep build --file $BicepTemplate --stdout 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Bicep template validation failed"
        exit 1
    }
    
    Write-Success "Bicep template validation completed"
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

# Set defaults
if (-not $ResourceGroup) {
    $ResourceGroup = "rg-$ApplicationName-$Environment"
}

if (-not $Password) {
    $Password = New-SecurePassword
    Write-Warning "Auto-generated PostgreSQL password. Please save it securely."
}

# Set subscription if provided
if ($Subscription) {
    Write-Status "Setting Azure subscription to $Subscription"
    az account set --subscription $Subscription
}

# Display configuration
Write-Status "Deployment Configuration:"
Write-Host "  Environment: $Environment"
Write-Host "  Location: $Location"
Write-Host "  Resource Group: $ResourceGroup"
$currentSub = (az account show --query id -o tsv)
Write-Host "  Subscription: $currentSub"

# Check prerequisites
Test-Prerequisites

# Validate template
Test-BicepTemplate

# Create resource group
Write-Status "Creating resource group $ResourceGroup..."
$rgResult = az group create `
    --name $ResourceGroup `
    --location $Location `
    --tags Environment=$Environment Application=$ApplicationName `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create resource group"
    exit 1
}

Write-Success "Resource group created successfully"

# Validate deployment
Write-Status "Validating deployment..."
$validationResult = az deployment group validate `
    --resource-group $ResourceGroup `
    --template-file $BicepTemplate `
    --parameters environment=$Environment `
    --parameters postgresAdminPassword=$Password `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment validation failed"
    Write-Host $validationResult
    exit 1
}

Write-Success "Deployment validation completed"

# Exit if validate-only
if ($ValidateOnly) {
    Write-Success "Validation completed successfully. Exiting without deployment."
    exit 0
}

# Deploy infrastructure
Write-Status "Deploying infrastructure..."
$deploymentName = "todolist-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deploymentResult = az deployment group create `
    --name $deploymentName `
    --resource-group $ResourceGroup `
    --template-file $BicepTemplate `
    --parameters environment=$Environment `
    --parameters postgresAdminPassword=$Password `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed"
    Write-Host $deploymentResult
    exit 1
}

# Parse deployment result
$deployment = $deploymentResult | ConvertFrom-Json
$outputs = $deployment.properties.outputs

$containerAppUrl = $outputs.containerAppUrl.value
$registryLoginServer = $outputs.containerRegistryLoginServer.value
$keyVaultName = $outputs.keyVaultName.value

Write-Success "Infrastructure deployment completed successfully!"

# Display results
Write-Host @"

=== Deployment Results ===
Environment: $Environment
Resource Group: $ResourceGroup
Deployment Name: $deploymentName

Key Resources:
- Container App URL: $containerAppUrl
- Container Registry: $registryLoginServer
- Key Vault: $keyVaultName

Next Steps:
1. Build and push your container image:
   docker build -t todolist:latest .
   az acr login --name $registryLoginServer
   docker tag todolist:latest $registryLoginServer/todolist:latest
   docker push $registryLoginServer/todolist:latest

2. Update the container app with your image:
   az containerapp update \
     --name <container-app-name> \
     --resource-group $ResourceGroup \
     --image $registryLoginServer/todolist:latest

3. Access your application:
   $containerAppUrl

4. Monitor your application:
   Check the Azure portal for monitoring dashboards

"@

# Save deployment info
$deploymentInfoFile = "deployment-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$deploymentResult | Out-File -FilePath $deploymentInfoFile -Encoding UTF8
Write-Success "Deployment details saved to $deploymentInfoFile"

Write-Success "Deployment script completed successfully!"
