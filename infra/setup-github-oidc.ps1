# Automated GitHub OIDC Setup Script

# This PowerShell script automates the entire GitHub OIDC federated identity setup process
# Run this script after ensuring you're logged into Azure CLI

param(
    [Parameter(Mandatory = $true)]
    [string]$RepoOwner,
    
    [Parameter(Mandatory = $true)]
    [string]$RepoName,
    
    [Parameter()]
    [string]$AppName = "TodoList-GitHub-Actions",
    
    [Parameter()]
    [string[]]$Environments = @("production", "development")
)

# Colors for output
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Red = [System.ConsoleColor]::Red
$Blue = [System.ConsoleColor]::Blue

function Write-Status {
    param($Message, $Color = $Green)
    Write-Host "✅ $Message" -ForegroundColor $Color
}

function Write-Info {
    param($Message)
    Write-Host "ℹ️  $Message" -ForegroundColor $Blue
}

function Write-Warning {
    param($Message)
    Write-Host "⚠️  $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param($Message)
    Write-Host "❌ $Message" -ForegroundColor $Red
}

try {
    Write-Info "Starting GitHub OIDC Federated Identity setup for $RepoOwner/$RepoName"
    
    # Check Azure CLI login
    Write-Info "Checking Azure CLI authentication..."
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Error "Please login to Azure CLI first: az login"
        exit 1
    }
    Write-Status "Authenticated as: $($account.user.name)"
    
    # Get Azure context
    $subscriptionId = $account.id
    $tenantId = $account.tenantId
    Write-Status "Subscription: $subscriptionId"
    Write-Status "Tenant: $tenantId"
    
    # Create App Registration
    Write-Info "Creating Azure AD App Registration..."
    $appId = az ad app create --display-name $AppName --query appId -o tsv
    if (-not $appId) {
        Write-Error "Failed to create app registration"
        exit 1
    }
    Write-Status "Created app registration: $appId"
    
    # Create Service Principal
    Write-Info "Creating service principal..."
    $servicePrincipalId = az ad sp create --id $appId --query id -o tsv
    if (-not $servicePrincipalId) {
        Write-Error "Failed to create service principal"
        exit 1
    }
    Write-Status "Created service principal: $servicePrincipalId"
    
    # Get App Object ID
    $appObjectId = az ad app show --id $appId --query id -o tsv
    Write-Status "App Object ID: $appObjectId"
    
    # Assign Azure permissions
    Write-Info "Assigning Contributor role..."
    $roleAssignment = az role assignment create `
        --assignee $servicePrincipalId `
        --role "Contributor" `
        --scope "/subscriptions/$subscriptionId" 2>$null
    
    if ($roleAssignment) {
        Write-Status "Assigned Contributor role to service principal"
    } else {
        Write-Warning "Role assignment may have failed or already exists"
    }
    
    # Create federated credentials for each environment
    foreach ($env in $Environments) {
        Write-Info "Creating federated credential for environment: $env"
        
        $credentialName = "TodoList-$env-Environment"
        $subject = "repo:$RepoOwner/$RepoName" + ":environment:$env"
        
        $credentialJson = @{
            name = $credentialName
            issuer = "https://token.actions.githubusercontent.com"
            subject = $subject
            description = "GitHub Actions $env environment deployment"
            audiences = @("api://AzureADTokenExchange")
        } | ConvertTo-Json -Depth 3
        
        $tempFile = "credential-$env.json"
        $credentialJson | Out-File -FilePath $tempFile -Encoding UTF8
        
        $result = az ad app federated-credential create --id $appObjectId --parameters $tempFile 2>$null
        Remove-Item $tempFile -Force
        
        if ($result) {
            Write-Status "Created federated credential for $env environment"
        } else {
            Write-Warning "Failed to create federated credential for $env (may already exist)"
        }
    }
    
    # Also create credential for main branch (fallback)
    Write-Info "Creating federated credential for main branch..."
    $credentialJson = @{
        name = "TodoList-Main-Branch"
        issuer = "https://token.actions.githubusercontent.com"
        subject = "repo:$RepoOwner/$RepoName" + ":ref:refs/heads/main"
        description = "GitHub Actions main branch deployment"
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Depth 3
    
    $tempFile = "credential-main.json"
    $credentialJson | Out-File -FilePath $tempFile -Encoding UTF8
    
    $result = az ad app federated-credential create --id $appObjectId --parameters $tempFile 2>$null
    Remove-Item $tempFile -Force
    
    if ($result) {
        Write-Status "Created federated credential for main branch"
    } else {
        Write-Warning "Failed to create federated credential for main branch (may already exist)"
    }
    
    # Output GitHub configuration
    Write-Host "`n" -NoNewline
    Write-Host "🎉 Setup Complete! Configure your GitHub repository:" -ForegroundColor $Green
    Write-Host "─────────────────────────────────────────────────────" -ForegroundColor $Blue
    
    Write-Host "`nGitHub Repository Variables (Settings → Secrets and variables → Actions → Variables):" -ForegroundColor $Yellow
    Write-Host "AZURE_CLIENT_ID=$appId"
    Write-Host "AZURE_TENANT_ID=$tenantId"
    Write-Host "AZURE_SUBSCRIPTION_ID=$subscriptionId"
    
    Write-Host "`nGitHub Repository Secrets (Settings → Secrets and variables → Actions → Secrets):" -ForegroundColor $Yellow
    Write-Host "TF_VAR_postgres_admin_password=[generate-secure-password]"
    
    Write-Host "`nGitHub Environments to create (Settings → Environments):" -ForegroundColor $Yellow
    foreach ($env in $Environments) {
        Write-Host "- $env"
    }
    
    Write-Host "`nNext Steps:" -ForegroundColor $Blue
    Write-Host "1. Add the above variables and secrets to your GitHub repository"
    Write-Host "2. Create the GitHub environments listed above"
    Write-Host "3. Push to main branch or create a PR to trigger the workflow"
    Write-Host "4. Monitor the deployment in GitHub Actions"
    
    Write-Host "`nVerification Commands:" -ForegroundColor $Blue
    Write-Host "az ad app federated-credential list --id $appObjectId"
    Write-Host "az role assignment list --assignee $servicePrincipalId"
    
} catch {
    Write-Error "Setup failed: $($_.Exception.Message)"
    exit 1
}
