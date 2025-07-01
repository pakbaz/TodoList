# GitHub Secrets Setup Script for TodoList Azure Deployment
# This script helps set up the required GitHub secrets for Azure deployment using OIDC

Write-Host "GitHub Secrets Setup for TodoList Azure Deployment" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green

# Check if GitHub CLI is available
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ GitHub CLI (gh) is not installed or not in PATH" -ForegroundColor Red
    Write-Host "📥 Please install GitHub CLI from: https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

# Check if logged in to GitHub CLI
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not logged in to GitHub CLI" -ForegroundColor Red
    Write-Host "🔑 Please run: gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ GitHub CLI is available and authenticated" -ForegroundColor Green

# Get repository information
try {
    $repoInfo = gh repo view --json owner,name | ConvertFrom-Json
    $repo = "$($repoInfo.owner.login)/$($repoInfo.name)"
    Write-Host "📁 Repository: $repo" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Could not detect repository. Make sure you're in a Git repository with GitHub remote." -ForegroundColor Red
    exit 1
}

# Prompt for Azure configuration
Write-Host "`n🔧 Azure Configuration Required" -ForegroundColor Yellow
Write-Host "You need to provide the following Azure details for OIDC authentication:"

$azureClientId = Read-Host "Enter Azure Client ID (Application ID)"
$azureTenantId = Read-Host "Enter Azure Tenant ID (Directory ID)"
$azureSubscriptionId = Read-Host "Enter Azure Subscription ID"

# Validate inputs
if ([string]::IsNullOrWhiteSpace($azureClientId) -or 
    [string]::IsNullOrWhiteSpace($azureTenantId) -or 
    [string]::IsNullOrWhiteSpace($azureSubscriptionId)) {
    Write-Host "❌ All Azure IDs are required" -ForegroundColor Red
    exit 1
}

# Optional: Generate a secure database password
$generatePassword = Read-Host "Generate secure database password? (y/n) [y]"
if ($generatePassword -eq "" -or $generatePassword.ToLower() -eq "y") {
    Add-Type -AssemblyName System.Web
    $dbPassword = [System.Web.Security.Membership]::GeneratePassword(24, 8)
    Write-Host "🔒 Generated secure database password" -ForegroundColor Green
} else {
    $dbPassword = Read-Host "Enter database password" -AsSecureString
    $dbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword))
}

# Secrets to set
$secrets = @{
    "AZURE_CLIENT_ID" = $azureClientId
    "AZURE_TENANT_ID" = $azureTenantId
    "AZURE_SUBSCRIPTION_ID" = $azureSubscriptionId
    "DATABASE_PASSWORD" = $dbPassword
}

# Repository variables to set
$defaultLocation = Read-Host "Enter Azure location [eastus]"
if ([string]::IsNullOrWhiteSpace($defaultLocation)) {
    $defaultLocation = "eastus"
}

$variables = @{
    "AZURE_LOCATION" = $defaultLocation
}

Write-Host "`n🔐 Setting GitHub Secrets..." -ForegroundColor Yellow

foreach ($secretName in $secrets.Keys) {
    $secretValue = $secrets[$secretName]
    try {
        $result = gh secret set $secretName --body $secretValue --repo $repo
        Write-Host "✅ Set secret: $secretName" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to set secret: $secretName" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n📊 Setting GitHub Variables..." -ForegroundColor Yellow

foreach ($varName in $variables.Keys) {
    $varValue = $variables[$varName]
    try {
        $result = gh variable set $varName --body $varValue --repo $repo
        Write-Host "✅ Set variable: $varName = $varValue" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to set variable: $varName" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n🎉 GitHub secrets and variables setup complete!" -ForegroundColor Green
Write-Host "📋 Summary:" -ForegroundColor Cyan
Write-Host "   Repository: $repo" -ForegroundColor Gray
Write-Host "   Secrets set: $($secrets.Keys -join ', ')" -ForegroundColor Gray
Write-Host "   Variables set: $($variables.Keys -join ', ')" -ForegroundColor Gray
Write-Host "`n📖 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Configure federated identity credentials in Azure" -ForegroundColor Gray
Write-Host "   2. Assign appropriate Azure roles to the service principal" -ForegroundColor Gray
Write-Host "   3. Push to main branch or trigger workflow manually" -ForegroundColor Gray
Write-Host "`n📚 For detailed setup instructions, see:" -ForegroundColor Yellow
Write-Host "   docs/deployment-bestpractices.md" -ForegroundColor Gray
    
    try {
        gh secret set $secretName --body $secretValue --repo $repo
        Write-Host "Success: $secretName" -ForegroundColor Green
    }
    catch {
        Write-Host "Error setting $secretName : $_" -ForegroundColor Red
    }
}

Write-Host "`nSetting GitHub Variables..." -ForegroundColor Yellow

foreach ($varName in $variables.Keys) {
    $varValue = $variables[$varName]
    Write-Host "Setting variable: $varName" -ForegroundColor Gray
    
    try {
        gh variable set $varName --body $varValue --repo $repo
        Write-Host "Success: $varName" -ForegroundColor Green
    }
    catch {
        Write-Host "Error setting $varName : $_" -ForegroundColor Red
    }
}

Write-Host "`nGitHub Secrets and Variables Setup Complete!" -ForegroundColor Green
Write-Host "You can now run GitHub Actions workflows for deployment" -ForegroundColor Cyan

# Verify the setup
Write-Host "`nVerifying setup..." -ForegroundColor Yellow
try {
    gh secret list --repo $repo
    Write-Host "Variables:" -ForegroundColor Cyan
    gh variable list --repo $repo
}
catch {
    Write-Host "Could not verify setup: $_" -ForegroundColor Yellow
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Push your code to the main branch to trigger deployment" -ForegroundColor White
Write-Host "2. Monitor the GitHub Actions workflow in your repository" -ForegroundColor White
Write-Host "3. Check the deployment status in the Azure portal" -ForegroundColor White
