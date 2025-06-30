# OIDC Setup Verification Script
# This script verifies that the Azure AD application and federated credentials are properly configured

param(
    [Parameter(Mandatory=$false)]
    [string]$AppName = "TodoList-GitHub-Actions-OIDC",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubOrg = "pakbaz",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = "TodoList"
)

# Colors
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Reset = "`e[0m"

function Write-Status { param($Message) Write-Host "$Green✓$Reset $Message" }
function Write-Warning { param($Message) Write-Host "$Yellow⚠$Reset $Message" }
function Write-Error { param($Message) Write-Host "$Red✗$Reset $Message" }

Write-Host "🔍 Verifying GitHub OIDC Setup for Azure"
Write-Host "=========================================="

# Check Azure CLI authentication
try {
    $account = az account show | ConvertFrom-Json
    Write-Status "Azure CLI authentication verified"
} catch {
    Write-Error "Not logged into Azure. Run 'az login' first."
    exit 1
}

# Get application details
Write-Host "`n📱 Application Registration:"
$appDetails = az ad app list --display-name $AppName --query "[0]" 2>$null | ConvertFrom-Json

if (-not $appDetails) {
    Write-Error "Application '$AppName' not found"
    exit 1
}

$appId = $appDetails.appId
$objectId = $appDetails.id
Write-Status "Application found: $appId"

# Check service principal
Write-Host "`n👤 Service Principal:"
$spDetails = az ad sp list --filter "appId eq '$appId'" --query "[0]" 2>$null | ConvertFrom-Json

if (-not $spDetails) {
    Write-Error "Service principal not found for application"
    exit 1
}

$spId = $spDetails.id
Write-Status "Service principal found: $spId"

# Check role assignments
Write-Host "`n🔐 Role Assignments:"
$roleAssignments = az role assignment list --assignee $appId --query "[?roleDefinitionName=='Contributor']" 2>$null | ConvertFrom-Json

if ($roleAssignments.Count -gt 0) {
    $scope = $roleAssignments[0].scope
    Write-Status "Contributor role assigned to: $scope"
} else {
    Write-Warning "No Contributor role assignments found"
}

# Check federated credentials
Write-Host "`n🔗 Federated Credentials:"
$federatedCreds = az ad app federated-credential list --id $objectId 2>$null | ConvertFrom-Json

$expectedCreds = @(
    "main-branch",
    "pull-requests", 
    "dev-environment",
    "staging-environment",
    "production-environment"
)

foreach ($credName in $expectedCreds) {
    $cred = $federatedCreds | Where-Object { $_.name -eq $credName }
    if ($cred) {
        Write-Status "$credName`: $($cred.subject)"
    } else {
        Write-Error "$credName`: Not found"
    }
}

# Summary
Write-Host "`n📋 Configuration Summary:"
Write-Host "=========================="
Write-Host "Application ID: $appId"
Write-Host "Tenant ID: $(az account show --query tenantId -o tsv)"
Write-Host "Subscription ID: $(az account show --query id -o tsv)"

Write-Host "`n🚀 GitHub Repository Setup:"
Write-Host "=============================="
Write-Host "1. Go to: https://github.com/$GitHubOrg/$GitHubRepo/settings/secrets/actions"
Write-Host "2. Add these secrets:"
Write-Host "   - AZURE_CLIENT_ID: $appId"
Write-Host "   - AZURE_TENANT_ID: $(az account show --query tenantId -o tsv)"
Write-Host "   - AZURE_SUBSCRIPTION_ID: $(az account show --query id -o tsv)"
Write-Host "   - POSTGRES_ADMIN_PASSWORD: [your-secure-password]"

Write-Host "`n✨ OIDC setup verification completed!"
