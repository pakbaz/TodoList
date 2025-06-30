# Azure OIDC Setup Script for GitHub Actions (PowerShell)
# This script sets up Azure AD Application and Federated Identity for secure GitHub Actions deployment

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubOrg,
    
    [Parameter(Mandatory=$true)]
    [string]$GitHubRepo,
    
    [Parameter(Mandatory=$false)]
    [string]$AzureLocation = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "dev"
)

# Color output functions
function Write-ColorOutput([string]$Message, [string]$Color = "White") {
    switch ($Color) {
        "Red" { Write-Host $Message -ForegroundColor Red }
        "Green" { Write-Host $Message -ForegroundColor Green }
        "Yellow" { Write-Host $Message -ForegroundColor Yellow }
        "Blue" { Write-Host $Message -ForegroundColor Blue }
        "Cyan" { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

Write-ColorOutput "🚀 Azure OIDC Setup for TodoList Application" "Blue"
Write-ColorOutput "==================================================" "Blue"

# Check if user is logged in to Azure
try {
    $null = az account show 2>$null
} catch {
    Write-ColorOutput "❌ Please login to Azure first: az login" "Red"
    exit 1
}

# Get current subscription info
$subscriptionId = az account show --query id --output tsv
$subscriptionName = az account show --query name --output tsv
$tenantId = az account show --query tenantId --output tsv

Write-ColorOutput "✅ Azure Subscription: $subscriptionName ($subscriptionId)" "Green"
Write-ColorOutput "✅ Tenant ID: $tenantId" "Green"

# Generate resource names
$resourceGroup = "rg-todolist-$EnvironmentName"
$appName = "GithubOIDC-TodoList-$EnvironmentName"

Write-Host ""
Write-ColorOutput "📋 Configuration:" "Yellow"
Write-Host "   Resource Group: $resourceGroup"
Write-Host "   Location: $AzureLocation"
Write-Host "   GitHub: $GitHubOrg/$GitHubRepo"
Write-Host "   Environment: $EnvironmentName"
Write-Host "   App Name: $appName"
Write-Host ""

$continue = Read-Host "Continue with this configuration? (y/N)"
if ($continue -ne "y" -and $continue -ne "Y") {
    Write-Host "Aborted."
    exit 1
}

Write-ColorOutput "📁 Creating Resource Group..." "Blue"
az group create --name $resourceGroup --location $AzureLocation --tags "environment=$EnvironmentName" "project=todolist"

Write-ColorOutput "🔐 Creating Azure AD Application..." "Blue"

# Create Azure AD application
$appId = az ad app create --display-name $appName --query appId --output tsv

Write-ColorOutput "✅ Created Azure AD App: $appId" "Green"

# Create service principal
az ad sp create --id $appId --query objectId --output tsv | Out-Null

Write-ColorOutput "✅ Created Service Principal" "Green"

# Assign Contributor role to the service principal on the resource group
az role assignment create `
    --assignee $appId `
    --role "Contributor" `
    --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"

Write-ColorOutput "✅ Assigned Contributor role" "Green"

# Create federated credential for main branch
Write-ColorOutput "🔗 Creating Federated Credentials..." "Blue"

# Main branch credential
$mainBranchCredential = @{
    name = "github-main"
    issuer = "https://token.actions.githubusercontent.com"
    subject = "repo:$GitHubOrg/${GitHubRepo}:ref:refs/heads/main"
    description = "GitHub Actions - Main Branch"
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Depth 3

az ad app federated-credential create --id $appId --parameters $mainBranchCredential

# Pull request credential
$prCredential = @{
    name = "github-pr"
    issuer = "https://token.actions.githubusercontent.com"
    subject = "repo:$GitHubOrg/${GitHubRepo}:pull_request"
    description = "GitHub Actions - Pull Requests"
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Depth 3

az ad app federated-credential create --id $appId --parameters $prCredential

# Environment-specific credential (if not dev)
if ($EnvironmentName -ne "dev") {
    $envCredential = @{
        name = "github-env-$EnvironmentName"
        issuer = "https://token.actions.githubusercontent.com"
        subject = "repo:$GitHubOrg/${GitHubRepo}:environment:$EnvironmentName"
        description = "GitHub Actions - $EnvironmentName Environment"
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Depth 3

    az ad app federated-credential create --id $appId --parameters $envCredential
}

Write-ColorOutput "✅ Created Federated Credentials" "Green"

Write-Host ""
Write-ColorOutput "🎉 Setup Complete!" "Green"
Write-ColorOutput "==================================================" "Green"
Write-Host ""
Write-ColorOutput "📋 GitHub Repository Variables (Settings > Secrets and variables > Actions > Variables):" "Yellow"
Write-Host ""
Write-Host "AZURE_CLIENT_ID: $appId"
Write-Host "AZURE_TENANT_ID: $tenantId"
Write-Host "AZURE_SUBSCRIPTION_ID: $subscriptionId"
Write-Host "AZURE_LOCATION: $AzureLocation"
Write-Host ""
Write-ColorOutput "🛡️ GitHub Environment Protection:" "Yellow"
Write-Host "1. Go to Settings > Environments"
Write-Host "2. Create environment: $EnvironmentName"
Write-Host "3. Add required reviewers if desired"
Write-Host "4. Add environment-specific variables if needed"
Write-Host ""
Write-ColorOutput "🚀 Ready to Deploy:" "Yellow"
Write-Host "1. Push your code to the main branch"
Write-Host "2. GitHub Actions will automatically deploy to Azure"
Write-Host "3. Monitor the deployment in the Actions tab"
Write-Host ""
Write-ColorOutput "💡 Next Steps:" "Blue"
Write-Host "- Review and adjust the Bicep templates in infra/"
Write-Host "- Customize the GitHub Actions workflows in .github/workflows/"
Write-Host "- Test the deployment with: gh workflow run `"Deploy to Azure`""
Write-Host ""
Write-ColorOutput "✅ All done! Happy deploying! 🚀" "Green"
