# GitHub OIDC Setup for Azure
# This script creates an Azure AD application registration with federated credentials for GitHub Actions
# Uses OpenID Connect (OIDC) for secure authentication without secrets

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubOrg,
    
    [Parameter(Mandatory=$true)]
    [string]$GitHubRepo,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$AppName = "TodoList-GitHub-Actions-OIDC"
)

# Colors for output
$Green = "`e[32m"
$Yellow = "`e[33m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param($Color, $Message)
    Write-Host "$Color$Message$Reset"
}

Write-ColorOutput $Green "Setting up GitHub OIDC with Azure Entra ID"
Write-ColorOutput $Yellow "Organization: $GitHubOrg"
Write-ColorOutput $Yellow "Repository: $GitHubRepo"

# Get current subscription and tenant if not provided
if (-not $SubscriptionId) {
    $SubscriptionId = (az account show --query id --output tsv)
    Write-ColorOutput $Yellow "Using current subscription: $SubscriptionId"
}

$TenantId = (az account show --query tenantId --output tsv)
Write-ColorOutput $Yellow "Tenant ID: $TenantId"

# Set the subscription
az account set --subscription $SubscriptionId

# Check if application already exists
Write-ColorOutput $Yellow "Checking if application '$AppName' already exists..."
$existingApp = az ad app list --display-name $AppName --query "[0]" 2>$null | ConvertFrom-Json

if ($existingApp) {
    Write-ColorOutput $Yellow "Application already exists with ID: $($existingApp.appId)"
    $AppId = $existingApp.appId
    $ObjectId = $existingApp.id
} else {
    # Create Azure AD Application Registration
    Write-ColorOutput $Yellow "Creating Azure AD Application Registration..."
    $app = az ad app create --display-name $AppName --query "{appId:appId,id:id}" | ConvertFrom-Json
    $AppId = $app.appId
    $ObjectId = $app.id
    Write-ColorOutput $Green "Created application with ID: $AppId"
}

# Create Service Principal
Write-ColorOutput $Yellow "Creating Service Principal..."
$spExists = az ad sp list --filter "appId eq '$AppId'" --query "[0].id" --output tsv 2>$null
if (-not $spExists) {
    $sp = az ad sp create --id $AppId --query "id" --output tsv
    Write-ColorOutput $Green "Created service principal: $sp"
} else {
    Write-ColorOutput $Yellow "Service principal already exists: $spExists"
    $sp = $spExists
}

# Assign Contributor role to the subscription
Write-ColorOutput $Yellow "Assigning Contributor role..."
try {
    az role assignment create --assignee $AppId --role "Contributor" --scope "/subscriptions/$SubscriptionId" 2>$null
    Write-ColorOutput $Green "Assigned Contributor role"
} catch {
    Write-ColorOutput $Yellow "Role assignment may already exist"
}

# Create federated credentials for different GitHub environments
$credentials = @(
    @{
        name = "main-branch"
        subject = "repo:$GitHubOrg/${GitHubRepo}:ref:refs/heads/main"
        description = "Main branch deployments"
    },
    @{
        name = "pull-requests"
        subject = "repo:$GitHubOrg/${GitHubRepo}:pull_request"
        description = "Pull request builds"
    },
    @{
        name = "dev-environment"
        subject = "repo:$GitHubOrg/${GitHubRepo}:environment:dev"
        description = "Dev environment deployments"
    },
    @{
        name = "staging-environment"
        subject = "repo:$GitHubOrg/${GitHubRepo}:environment:staging"
        description = "Staging environment deployments"
    },
    @{
        name = "production-environment"
        subject = "repo:$GitHubOrg/${GitHubRepo}:environment:production"
        description = "Production environment deployments"
    }
)

Write-ColorOutput $Yellow "Creating federated credentials..."
foreach ($cred in $credentials) {
    Write-ColorOutput $Yellow "Creating credential: $($cred.name)"
    
    # Check if credential already exists
    $existingCred = az ad app federated-credential list --id $ObjectId --query "[?name=='$($cred.name)']" | ConvertFrom-Json
    
    if ($existingCred.Count -eq 0) {
        $credBody = @{
            name = $cred.name
            issuer = "https://token.actions.githubusercontent.com"
            subject = $cred.subject
            description = $cred.description
            audiences = @("api://AzureADTokenExchange")
        } | ConvertTo-Json -Depth 3
        
        $credBody | az ad app federated-credential create --id $ObjectId --parameters "@-" | Out-Null
        Write-ColorOutput $Green "  Created: $($cred.name)"
    } else {
        Write-ColorOutput $Yellow "  Already exists: $($cred.name)"
    }
}

# Output GitHub Actions secrets/variables
Write-ColorOutput $Green "`nGitHub Repository Configuration"
Write-ColorOutput $Green "================================================"
Write-ColorOutput $Yellow "Add these secrets to your GitHub repository:"
Write-ColorOutput $Yellow "($GitHubOrg/$GitHubRepo -> Settings -> Secrets and variables -> Actions)"
Write-ColorOutput $Reset ""

Write-Host "AZURE_CLIENT_ID: " -NoNewline
Write-ColorOutput $Green $AppId

Write-Host "AZURE_TENANT_ID: " -NoNewline
Write-ColorOutput $Green $TenantId

Write-Host "AZURE_SUBSCRIPTION_ID: " -NoNewline
Write-ColorOutput $Green $SubscriptionId

Write-ColorOutput $Reset "`nRepository Variables (optional but recommended):"
Write-Host "AZURE_RESOURCE_GROUP: " -NoNewline
Write-ColorOutput $Green "rg-todolist-dev"

Write-Host "AZURE_LOCATION: " -NoNewline
Write-ColorOutput $Green "eastus"

# Create a summary file
$summaryFile = "azure-github-oidc-setup.json"
$summary = @{
    appName = $AppName
    appId = $AppId
    tenantId = $TenantId
    subscriptionId = $SubscriptionId
    gitHubOrg = $GitHubOrg
    gitHubRepo = $GitHubRepo
    createdAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    secrets = @{
        AZURE_CLIENT_ID = $AppId
        AZURE_TENANT_ID = $TenantId
        AZURE_SUBSCRIPTION_ID = $SubscriptionId
    }
    variables = @{
        AZURE_RESOURCE_GROUP = "rg-todolist-dev"
        AZURE_LOCATION = "eastus"
    }
} | ConvertTo-Json -Depth 3

$summary | Out-File -FilePath $summaryFile -Encoding UTF8
Write-ColorOutput $Green "`nConfiguration saved to: $summaryFile"

Write-ColorOutput $Green "`nNext Steps:"
Write-ColorOutput $Reset "1. Add the secrets above to your GitHub repository"
Write-ColorOutput $Reset "2. Update your GitHub Actions workflow to use OIDC authentication"
Write-ColorOutput $Reset "3. Test the deployment pipeline"

Write-ColorOutput $Green "`nSetup completed successfully!"
