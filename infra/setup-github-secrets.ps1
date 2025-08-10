# GitHub Repository Secrets Setup Script - Best Practices
# This script configures GitHub repository secrets and variables for the TodoList project
# Following security best practices with least-privilege access

param(
    [Parameter()]
    [string]$ResourceGroupName = "rg-todolist-dev-centralus",
    
    [Parameter()]
    [string]$Location = "centralus",
    
    [Parameter()]
    [string]$Environment = "dev",
    
    [Parameter()]
    [string]$RepoOwner = "pakbaz",
    
    [Parameter()]
    [string]$RepoName = "TodoList"
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

function Generate-SecurePassword {
    param([int]$Length = 16)
    
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $password = ""
    
    # Ensure at least one of each character type
    $password += Get-Random -InputObject "abcdefghijklmnopqrstuvwxyz".ToCharArray()
    $password += Get-Random -InputObject "ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
    $password += Get-Random -InputObject "0123456789".ToCharArray()
    $password += Get-Random -InputObject "!@#$%^&*".ToCharArray()
    
    # Fill the rest randomly
    for ($i = 4; $i -lt $Length; $i++) {
        $password += Get-Random -InputObject $chars.ToCharArray()
    }
    
    # Shuffle the password
    $passwordArray = $password.ToCharArray()
    for ($i = $passwordArray.Length - 1; $i -gt 0; $i--) {
        $j = Get-Random -Maximum ($i + 1)
        $temp = $passwordArray[$i]
        $passwordArray[$i] = $passwordArray[$j]
        $passwordArray[$j] = $temp
    }
    
    return -join $passwordArray
}

try {
    Write-Info "Setting up GitHub repository secrets and variables for $RepoOwner/$RepoName"
    Write-Info "Target Resource Group: $ResourceGroupName"
    Write-Info "Location: $Location"
    Write-Info "Environment: $Environment"
    
    # Check prerequisites
    Write-Info "Checking prerequisites..."
    
    # Check Azure CLI
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        Write-Error "Please login to Azure CLI first: az login"
        exit 1
    }
    Write-Status "Azure CLI authenticated as: $($azAccount.user.name)"
    
    # Check GitHub CLI
    $ghStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "GitHub CLI not authenticated. Please run: gh auth login"
        Write-Info "Continuing with manual configuration output..."
        $useGhCli = $false
    } else {
        Write-Status "GitHub CLI authenticated"
        $useGhCli = $true
    }
    
    # Get Azure context
    $subscriptionId = $azAccount.id
    $tenantId = $azAccount.tenantId
    
    # Get existing app registration details
    $appName = "TodoList-GitHub-Actions"
    $apps = az ad app list --display-name $appName --query "[0]" | ConvertFrom-Json
    
    if (-not $apps -or -not $apps.appId) {
        Write-Error "App registration '$appName' not found. Please run setup-github-oidc.ps1 first."
        exit 1
    }
    
    $appId = $apps.appId
    $appObjectId = $apps.id
    Write-Status "Found app registration: $appId"
    
    # Get service principal
    $sp = az ad sp list --filter "appId eq '$appId'" --query "[0]" | ConvertFrom-Json
    $servicePrincipalId = $sp.id
    Write-Status "Found service principal: $servicePrincipalId"
    
    # Create resource group if it doesn't exist
    Write-Info "Ensuring resource group exists..."
    $rg = az group show --name $ResourceGroupName 2>$null | ConvertFrom-Json
    if (-not $rg) {
        Write-Info "Creating resource group: $ResourceGroupName"
        az group create --name $ResourceGroupName --location $Location | Out-Null
        Write-Status "Created resource group: $ResourceGroupName"
    } else {
        Write-Status "Resource group already exists: $ResourceGroupName"
    }
    
    # Assign least-privilege permissions to the specific resource group
    Write-Info "Configuring least-privilege Azure permissions..."
    
    # Required roles for Container Apps deployment
    $roles = @(
        "Contributor",                    # For resource management
        "User Access Administrator"       # For managed identity role assignments
    )
    
    foreach ($role in $roles) {
        Write-Info "Assigning '$role' role to resource group scope..."
        $assignment = az role assignment create `
            --assignee $servicePrincipalId `
            --role $role `
            --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName" 2>$null
        
        if ($assignment) {
            Write-Status "Assigned '$role' role to resource group"
        } else {
            Write-Warning "Role '$role' may already be assigned or assignment failed"
        }
    }
    
    # Generate secure PostgreSQL password
    Write-Info "Generating secure PostgreSQL password..."
    $postgresPassword = Generate-SecurePassword -Length 20
    Write-Status "Generated secure PostgreSQL password (20 characters)"
    
    # Prepare GitHub configuration
    $repoUrl = "https://github.com/$RepoOwner/$RepoName"
    
    # Variables (non-sensitive)
    $variables = @{
        "AZURE_CLIENT_ID" = $appId
        "AZURE_TENANT_ID" = $tenantId
        "AZURE_SUBSCRIPTION_ID" = $subscriptionId
        "AZURE_RESOURCE_GROUP" = $ResourceGroupName
        "AZURE_LOCATION" = $Location
        "ENVIRONMENT" = $Environment
    }
    
    # Secrets (sensitive)
    $secrets = @{
        "TF_VAR_postgres_admin_password" = $postgresPassword
    }
    
    if ($useGhCli) {
        Write-Info "Configuring GitHub repository using GitHub CLI..."
        
        # Set repository variables
        foreach ($var in $variables.GetEnumerator()) {
            Write-Info "Setting variable: $($var.Key)"
            $result = gh variable set $var.Key --body $var.Value --repo "$RepoOwner/$RepoName" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Status "Set variable: $($var.Key)"
            } else {
                Write-Warning "Failed to set variable $($var.Key): $result"
            }
        }
        
        # Set repository secrets
        foreach ($secret in $secrets.GetEnumerator()) {
            Write-Info "Setting secret: $($secret.Key)"
            $result = gh secret set $secret.Key --body $secret.Value --repo "$RepoOwner/$RepoName" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Status "Set secret: $($secret.Key)"
            } else {
                Write-Warning "Failed to set secret $($secret.Key): $result"
            }
        }
        
        # Create GitHub environments
        $environments = @("production", "development")
        foreach ($env in $environments) {
            Write-Info "Creating GitHub environment: $env"
            # Note: GitHub CLI doesn't have direct environment creation, but we can use API
            $envResult = gh api repos/$RepoOwner/$RepoName/environments/$env --method PUT 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Status "Created/updated environment: $env"
            } else {
                Write-Warning "Failed to create environment $env (may need manual creation)"
            }
        }
        
        Write-Status "GitHub repository configuration completed via GitHub CLI!"
        
    } else {
        Write-Warning "GitHub CLI not available. Please configure manually:"
    }
    
    # Always output manual configuration steps
    Write-Host "`n" -NoNewline
    Write-Host "🔧 GitHub Repository Configuration" -ForegroundColor $Blue
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor $Blue
    Write-Host "Repository: $repoUrl" -ForegroundColor $Yellow
    
    Write-Host "`n📋 Variables (Settings → Secrets and variables → Actions → Variables):" -ForegroundColor $Yellow
    foreach ($var in $variables.GetEnumerator()) {
        Write-Host "$($var.Key) = $($var.Value)"
    }
    
    Write-Host "`n🔐 Secrets (Settings → Secrets and variables → Actions → Secrets):" -ForegroundColor $Yellow
    foreach ($secret in $secrets.GetEnumerator()) {
        if ($secret.Key -eq "TF_VAR_postgres_admin_password") {
            Write-Host "$($secret.Key) = $($secret.Value)" -ForegroundColor $Green
        } else {
            Write-Host "$($secret.Key) = [REDACTED]"
        }
    }
    
    Write-Host "`n🌍 GitHub Environments to create:" -ForegroundColor $Yellow
    Write-Host "- production (with protection rules recommended)"
    Write-Host "- development"
    
    # Update Terraform variables for the specific configuration
    Write-Info "Updating Terraform variables for your configuration..."
    
    $tfVarsContent = @"
# Environment Configuration
environment = "$Environment"
location = "$Location"

# Resource Group (will be created if doesn't exist)
resource_group_name = "$ResourceGroupName"

# PostgreSQL Configuration
postgres_admin_username = "todolist_admin"
postgres_sku_name = "B_Standard_B1ms"
postgres_storage_mb = 32768
postgres_backup_retention_days = 7
postgres_geo_redundant_backup_enabled = false

# Container App Configuration
container_cpu = 0.5
container_memory = "1.0Gi"
autoscale_min_replicas = 0
autoscale_max_replicas = 3

# ACR Configuration
acr_sku = "Basic"

# Networking
enable_vnet = true
"@

    $tfVarsPath = "terraform.tfvars.example"
    $tfVarsContent | Out-File -FilePath $tfVarsPath -Encoding UTF8
    Write-Status "Created Terraform variables example: $tfVarsPath"
    
    Write-Host "`n" -NoNewline
    Write-Host "🎯 Next Steps:" -ForegroundColor $Blue
    Write-Host "1. Configure the GitHub variables and secrets shown above"
    Write-Host "2. Create the GitHub environments (production, development)"
    Write-Host "3. Copy terraform.tfvars.example to terraform.tfvars (optional)"
    Write-Host "4. Trigger deployment: push to main branch or run workflow manually"
    Write-Host "5. Monitor deployment in GitHub Actions tab"
    
    Write-Host "`n🛡️ Security Best Practices Applied:" -ForegroundColor $Green
    Write-Host "✅ Least-privilege access (scoped to specific resource group)"
    Write-Host "✅ Secure password generation (20 chars with complexity)"
    Write-Host "✅ Separation of variables (public) and secrets (private)"
    Write-Host "✅ Environment-specific configuration"
    Write-Host "✅ OIDC authentication (no long-lived secrets)"
    
    Write-Host "`n📊 Verification Commands:" -ForegroundColor $Blue
    Write-Host "# Check Azure permissions:"
    Write-Host "az role assignment list --assignee $servicePrincipalId --scope /subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName"
    Write-Host ""
    Write-Host "# Check GitHub configuration:"
    Write-Host "gh variable list --repo $RepoOwner/$RepoName"
    Write-Host "gh secret list --repo $RepoOwner/$RepoName"
    
} catch {
    Write-Error "Setup failed: $($_.Exception.Message)"
    exit 1
}
