# Terraform State Recovery Script
# This script helps import existing Azure resources into Terraform state

param(
    [string]$ResourceGroup = "rg-todolist-dev-centralus"
)

Write-Host "🔄 Terraform State Recovery for existing resources" -ForegroundColor Blue
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow

# Navigate to infra directory
Set-Location -Path "infra"

try {
    # Initialize Terraform
    Write-Host "`n1️⃣ Initializing Terraform..." -ForegroundColor Green
    terraform init

    # Get existing resources from Azure
    Write-Host "`n2️⃣ Scanning existing Azure resources..." -ForegroundColor Green
    $resources = az resource list --resource-group $ResourceGroup --query "[].{name:name, type:type, id:id}" | ConvertFrom-Json

    if ($resources.Count -eq 0) {
        Write-Host "✅ No existing resources found. Safe to run terraform plan." -ForegroundColor Green
        exit 0
    }

    Write-Host "Found $($resources.Count) existing resources:" -ForegroundColor Yellow
    $resources | ForEach-Object { Write-Host "  - $($_.name) ($($_.type))" }

    # Show import commands (don't auto-execute to avoid mistakes)
    Write-Host "`n3️⃣ To import these resources, run these commands:" -ForegroundColor Green
    Write-Host "(Review each command carefully before executing)" -ForegroundColor Yellow

    foreach ($resource in $resources) {
        $terraformAddress = ""
        
        switch -Regex ($resource.type) {
            "Microsoft.Resources/resourceGroups" { 
                $terraformAddress = "azurerm_resource_group.main"
            }
            "Microsoft.ContainerRegistry/registries" { 
                $terraformAddress = "azurerm_container_registry.main"
            }
            "Microsoft.DBforPostgreSQL/flexibleServers" { 
                $terraformAddress = "module.postgres.azurerm_postgresql_flexible_server.main"
            }
            "Microsoft.ManagedIdentity/userAssignedIdentities" { 
                $terraformAddress = "azurerm_user_assigned_identity.main"
            }
            "Microsoft.OperationalInsights/workspaces" { 
                $terraformAddress = "module.monitoring.azurerm_log_analytics_workspace.main"
            }
            "Microsoft.KeyVault/vaults" { 
                $terraformAddress = "azurerm_key_vault.main"
            }
            "Microsoft.Insights/components" { 
                $terraformAddress = "module.monitoring.azurerm_application_insights.main"
            }
            "Microsoft.App/managedEnvironments" { 
                $terraformAddress = "module.container_app.azurerm_container_app_environment.main"
            }
            "Microsoft.App/containerApps" { 
                $terraformAddress = "module.container_app.azurerm_container_app.main"
            }
        }
        
        if ($terraformAddress) {
            Write-Host "terraform import '$terraformAddress' '$($resource.id)'" -ForegroundColor Cyan
        }
    }

    Write-Host "`n⚠️  WARNING: Import can be complex. Consider Option 2 (clean slate) if you're not attached to existing resources." -ForegroundColor Red

} catch {
    Write-Error "Failed to analyze resources: $($_.Exception.Message)"
}

Write-Host "`n🎯 Alternative Options:" -ForegroundColor Blue
Write-Host "1. Import existing resources (complex but preserves data)"
Write-Host "2. Delete existing resources and redeploy (simple but loses data)"
Write-Host "3. Use different resource group name in terraform.tfvars"
