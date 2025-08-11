# PowerShell script to add GitHub secret for PostgreSQL admin password
# Run this script from the root directory of your repository

param(
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [Parameter(Mandatory=$false)]
    [string]$Owner = "sepehrpakbaz",
    
    [Parameter(Mandatory=$false)]
    [string]$Repo = "TodoList"
)

# Validate password complexity
if ($Password.Length -lt 8) {
    Write-Error "Password must be at least 8 characters long"
    exit 1
}

if (-not ($Password -match '[A-Z]' -and $Password -match '[a-z]' -and $Password -match '[0-9]' -and $Password -match '[^A-Za-z0-9]')) {
    Write-Error "Password must contain uppercase, lowercase, numbers, and special characters"
    exit 1
}

Write-Host "Adding GitHub secret POSTGRES_ADMIN_PASSWORD..." -ForegroundColor Green

try {
    # Add the secret
    gh secret set POSTGRES_ADMIN_PASSWORD --body $Password --repo "$Owner/$Repo"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully added POSTGRES_ADMIN_PASSWORD secret" -ForegroundColor Green
        
        # List all secrets to confirm
        Write-Host "`nCurrent GitHub secrets:" -ForegroundColor Cyan
        gh secret list --repo "$Owner/$Repo"
    } else {
        Write-Error "Failed to add secret"
        exit 1
    }
}
catch {
    Write-Error "Error adding secret: $_"
    exit 1
}

Write-Host "`n🔐 Secret added successfully! The CI/CD pipeline can now use the PostgreSQL password." -ForegroundColor Green
Write-Host "⚠️  Remember: Never commit passwords to your repository!" -ForegroundColor Yellow
