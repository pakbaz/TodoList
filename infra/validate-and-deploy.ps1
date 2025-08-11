# Manual Terraform Validation and Deployment Script
# Run this script step by step to validate and deploy your infrastructure

Write-Host "=== TodoList Azure Infrastructure Deployment ===" -ForegroundColor Green
Write-Host ""

# Step 1: Check Prerequisites
Write-Host "Step 1: Checking Prerequisites..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Checking Azure CLI..." -ForegroundColor Cyan
try {
    $azVersion = az version --output table 2>$null
    if ($azVersion) {
        Write-Host "✅ Azure CLI is installed" -ForegroundColor Green
    } else {
        Write-Host "❌ Azure CLI not found. Please install from: https://aka.ms/installazurecliwindows" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Azure CLI not found. Please install from: https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}

Write-Host "Checking Terraform..." -ForegroundColor Cyan
try {
    $tfVersion = terraform version 2>$null
    if ($tfVersion) {
        Write-Host "✅ Terraform is installed" -ForegroundColor Green
        Write-Host "Version: $($tfVersion[0])" -ForegroundColor Gray
    } else {
        Write-Host "❌ Terraform not found. Please install from: https://learn.hashicorp.com/tutorials/terraform/install-cli" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Terraform not found. Please install from: https://learn.hashicorp.com/tutorials/terraform/install-cli" -ForegroundColor Red
    exit 1
}

Write-Host "Checking Docker..." -ForegroundColor Cyan
try {
    $dockerVersion = docker version --format "{{.Client.Version}}" 2>$null
    if ($dockerVersion) {
        Write-Host "✅ Docker is installed" -ForegroundColor Green
        Write-Host "Version: $dockerVersion" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  Docker not found. You'll need it for container deployment." -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Docker not found. You'll need it for container deployment." -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Azure Authentication
Write-Host "Step 2: Azure Authentication..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Checking Azure authentication..." -ForegroundColor Cyan
try {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if ($account) {
        Write-Host "✅ Already logged into Azure" -ForegroundColor Green
        Write-Host "Subscription: $($account.name)" -ForegroundColor Gray
        Write-Host "Tenant: $($account.tenantId)" -ForegroundColor Gray
    } else {
        Write-Host "❌ Not logged into Azure. Please run:" -ForegroundColor Red
        Write-Host "   az login" -ForegroundColor White
        Write-Host "   az account set --subscription 'your-subscription-id'" -ForegroundColor White
        exit 1
    }
} catch {
    Write-Host "❌ Azure authentication failed. Please run:" -ForegroundColor Red
    Write-Host "   az login" -ForegroundColor White
    Write-Host "   az account set --subscription 'your-subscription-id'" -ForegroundColor White
    exit 1
}

Write-Host ""

# Step 3: Directory Setup
Write-Host "Step 3: Setting up working directory..." -ForegroundColor Yellow
Write-Host ""

$scriptPath = $PSScriptRoot
if (-not $scriptPath) {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$projectRoot = Split-Path -Parent $scriptPath
$infraPath = Join-Path $projectRoot "infra"

Write-Host "Project root: $projectRoot" -ForegroundColor Gray
Write-Host "Infrastructure path: $infraPath" -ForegroundColor Gray

if (-not (Test-Path $infraPath)) {
    Write-Host "❌ Infrastructure directory not found: $infraPath" -ForegroundColor Red
    exit 1
}

Set-Location $infraPath
Write-Host "✅ Changed to infrastructure directory" -ForegroundColor Green
Write-Host ""

# Step 4: Terraform Configuration
Write-Host "Step 4: Preparing Terraform configuration..." -ForegroundColor Yellow
Write-Host ""

# Check if terraform.tfvars exists
if (-not (Test-Path "terraform.tfvars")) {
    if (Test-Path "terraform.tfvars.example") {
        Write-Host "Creating terraform.tfvars from example..." -ForegroundColor Cyan
        Copy-Item "terraform.tfvars.example" "terraform.tfvars"
        Write-Host "✅ Created terraform.tfvars" -ForegroundColor Green
        Write-Host "⚠️  Please review and customize terraform.tfvars before proceeding!" -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host "❌ terraform.tfvars.example not found" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ terraform.tfvars already exists" -ForegroundColor Green
}

Write-Host ""

# Step 5: Terraform Initialization
Write-Host "Step 5: Initializing Terraform..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Running terraform init..." -ForegroundColor Cyan
try {
    $initOutput = terraform init 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Terraform initialized successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Terraform initialization failed:" -ForegroundColor Red
        Write-Host $initOutput -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Terraform initialization failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 6: Terraform Validation
Write-Host "Step 6: Validating Terraform configuration..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Running terraform validate..." -ForegroundColor Cyan
try {
    $validateOutput = terraform validate 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Terraform configuration is valid" -ForegroundColor Green
    } else {
        Write-Host "❌ Terraform validation failed:" -ForegroundColor Red
        Write-Host $validateOutput -ForegroundColor Red
        Write-Host ""
        Write-Host "Please fix the validation errors before proceeding." -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ Terraform validation failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 7: Terraform Format Check
Write-Host "Step 7: Checking Terraform formatting..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Running terraform fmt..." -ForegroundColor Cyan
try {
    $fmtOutput = terraform fmt -check -diff 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ All files are properly formatted" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Some files need formatting. Auto-formatting..." -ForegroundColor Yellow
        terraform fmt
        Write-Host "✅ Files have been formatted" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Terraform format check failed, but continuing..." -ForegroundColor Yellow
}

Write-Host ""

# Step 8: Terraform Plan
Write-Host "Step 8: Generating Terraform plan..." -ForegroundColor Yellow
Write-Host ""

Write-Host "This will show you what resources will be created..." -ForegroundColor Cyan
Write-Host "Running terraform plan..." -ForegroundColor Cyan

$planFile = "tfplan"
try {
    $planOutput = terraform plan -out=$planFile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Terraform plan generated successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "Plan saved to: $planFile" -ForegroundColor Gray
        Write-Host ""
        
        # Parse plan output for summary
        $planLines = $planOutput -split "`n"
        $summaryLine = $planLines | Where-Object { $_ -match "Plan:" }
        if ($summaryLine) {
            Write-Host "Plan Summary: $summaryLine" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Terraform plan failed:" -ForegroundColor Red
        Write-Host $planOutput -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Terraform plan failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 9: Cost Estimation
Write-Host "Step 9: Cost Estimation..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Estimated monthly costs (East US region):" -ForegroundColor Cyan
Write-Host "• Container Apps (1-5 replicas): ~$15-30/month" -ForegroundColor Gray
Write-Host "• PostgreSQL Flexible Server (B1ms): ~$25-40/month" -ForegroundColor Gray
Write-Host "• Container Registry (Basic): ~$5/month" -ForegroundColor Gray
Write-Host "• Application Insights: ~$2-10/month" -ForegroundColor Gray
Write-Host "• Key Vault: ~$1/month" -ForegroundColor Gray
Write-Host "• Log Analytics: ~$2-5/month" -ForegroundColor Gray
Write-Host ""
Write-Host "Total estimated range: $50-91/month" -ForegroundColor Yellow
Write-Host ""

# Step 10: Deployment Decision
Write-Host "Step 10: Ready for deployment!" -ForegroundColor Yellow
Write-Host ""

Write-Host "✅ All pre-deployment checks passed!" -ForegroundColor Green
Write-Host ""
Write-Host "To deploy the infrastructure, run:" -ForegroundColor Cyan
Write-Host "   terraform apply `"$planFile`"" -ForegroundColor White
Write-Host ""
Write-Host "To deploy without the plan file:" -ForegroundColor Cyan
Write-Host "   terraform apply" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  WARNING: This will create billable Azure resources!" -ForegroundColor Yellow
Write-Host ""

# Interactive deployment option
$deploy = Read-Host "Do you want to deploy now? (y/N)"
if ($deploy -eq "y" -or $deploy -eq "Y" -or $deploy -eq "yes") {
    Write-Host ""
    Write-Host "Deploying infrastructure..." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        terraform apply $planFile
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "🎉 Infrastructure deployed successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "1. Build and push your container image" -ForegroundColor White
            Write-Host "2. Update the Container App with your image" -ForegroundColor White
            Write-Host "3. Test the application endpoints" -ForegroundColor White
            Write-Host ""
            Write-Host "For detailed instructions, see DEPLOYMENT.md" -ForegroundColor Gray
        } else {
            Write-Host "❌ Deployment failed. Check the output above for details." -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "❌ Deployment failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "Deployment skipped. You can deploy later using:" -ForegroundColor Gray
    Write-Host "   terraform apply `"$planFile`"" -ForegroundColor White
    Write-Host ""
    Write-Host "Don't forget to clean up the plan file when done:" -ForegroundColor Gray
    Write-Host "   Remove-Item `"$planFile`"" -ForegroundColor White
}

Write-Host ""
Write-Host "=== Validation Complete ===" -ForegroundColor Green
