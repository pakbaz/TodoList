# GitHub Actions Setup Script
# Run this after creating the service principal manually

param(
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$PostgresPassword
)

# Set GitHub Variables
Write-Host "Setting GitHub Variables..." -ForegroundColor Green

try {
    gh variable set AZURE_SUBSCRIPTION_ID --body "31123a85-42f7-4b2c-a74f-3c580102fb48"
    gh variable set AZURE_TENANT_ID --body "16b3c013-d300-468d-ac64-7eda0820b6d3"
    gh variable set AZURE_CLIENT_ID --body $ClientId
    gh variable set AZURE_LOCATION --body "eastus"
    
    Write-Host "✅ GitHub Variables configured successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to set GitHub Variables: $($_.Exception.Message)" -ForegroundColor Red
}

# Set GitHub Secrets
Write-Host "Setting GitHub Secrets..." -ForegroundColor Green

try {
    gh secret set POSTGRES_ADMIN_PASSWORD --body $PostgresPassword
    
    Write-Host "✅ GitHub Secrets configured successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to set GitHub Secrets: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔧 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Verify the service principal has Contributor access to subscription"
Write-Host "2. Optionally configure federated credentials for enhanced security"
Write-Host "3. Create 'dev' environment in GitHub Repository Settings"
Write-Host "4. Trigger deployment with: gh workflow run deploy.yml"
Write-Host ""
Write-Host "📋 Test deployment:"
Write-Host "   gh run list"
Write-Host "   gh run watch <run-id>"
