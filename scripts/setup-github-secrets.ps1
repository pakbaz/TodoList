# GitHub Secrets Setup Script for TodoList Deployment
# Run this script to set up the required GitHub secrets for Azure deployment

Write-Host "Setting up GitHub Secrets for TodoList Deployment" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green

# Check if GitHub CLI is available
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "GitHub CLI (gh) is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install GitHub CLI from: https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

# Read configuration from azure-github-oidc-setup.json
$configPath = "azure-github-oidc-setup.json"
if (!(Test-Path $configPath)) {
    Write-Host "Configuration file not found: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json

# Repository info
$repoOwner = $config.gitHubOrg
$repoName = $config.gitHubRepo
$repo = "$repoOwner/$repoName"

Write-Host "Repository: $repo" -ForegroundColor Cyan
Write-Host "Subscription: $($config.subscriptionId)" -ForegroundColor Cyan
Write-Host "Tenant: $($config.tenantId)" -ForegroundColor Cyan

# Secrets to set
$secrets = @{
    "AZURE_CLIENT_ID" = $config.secrets.AZURE_CLIENT_ID
    "AZURE_TENANT_ID" = $config.secrets.AZURE_TENANT_ID  
    "AZURE_SUBSCRIPTION_ID" = $config.secrets.AZURE_SUBSCRIPTION_ID
    "POSTGRES_ADMIN_PASSWORD" = "TodoList2025!Secure#Pass"
}

# Variables to set
$variables = @{
    "AZURE_LOCATION" = $config.variables.AZURE_LOCATION
    "AZURE_RESOURCE_GROUP" = $config.variables.AZURE_RESOURCE_GROUP
}

Write-Host "`nSetting GitHub Secrets..." -ForegroundColor Yellow

foreach ($secretName in $secrets.Keys) {
    $secretValue = $secrets[$secretName]
    Write-Host "Setting secret: $secretName" -ForegroundColor Gray
    
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
