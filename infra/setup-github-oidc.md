# GitHub OIDC Federated Identity Setup Guide

This guide walks through setting up secure, passwordless authentication between GitHub Actions and Azure using OpenID Connect (OIDC) and Workload Identity Federation.

## 🔐 Why OIDC vs Service Principal Secrets?

**Traditional Method (Not Recommended)**:
- Store Azure service principal credentials as GitHub secrets
- Risk of secret exposure, rotation challenges
- Long-lived credentials that can be compromised

**OIDC/Workload Identity Federation (Recommended)**:
- ✅ **No secrets stored in GitHub** - tokens are short-lived and automatically generated
- ✅ **Zero Trust security** - each workflow run gets a unique, time-limited token
- ✅ **Fine-grained access control** - restrict access to specific repositories, branches, environments
- ✅ **Automatic rotation** - no manual credential management needed

## 🏗️ Architecture Overview

```
GitHub Actions Workflow
    ↓ (requests OIDC token)
GitHub OIDC Provider (https://token.actions.githubusercontent.com)
    ↓ (presents token)
Microsoft Entra ID Workload Identity Federation
    ↓ (validates & exchanges for Azure token)
Azure Resources (Container Apps, Key Vault, ACR, etc.)
```

## 📋 Step-by-Step Setup

### Step 1: Create Azure AD App Registration

```powershell
# Login to Azure
az login

# Set variables for your environment
$appName = "TodoList-GitHub-Actions"
$repoOwner = "pakbaz"  # Your GitHub username/org
$repoName = "TodoList"
$subscriptionId = $(az account show --query id -o tsv)
$tenantId = $(az account show --query tenantId -o tsv)

# Create the app registration
$appId = $(az ad app create --display-name $appName --query appId -o tsv)
Write-Host "✅ Created app registration: $appId"

# Create a service principal for the app
$servicePrincipalId = $(az ad sp create --id $appId --query id -o tsv)
Write-Host "✅ Created service principal: $servicePrincipalId"

# Get the app object ID (needed for federated credentials)
$appObjectId = $(az ad app show --id $appId --query id -o tsv)
Write-Host "✅ App Object ID: $appObjectId"
```

### Step 2: Assign Azure Permissions

```powershell
# Assign Contributor role for resource management (adjust scope as needed)
az role assignment create `
  --assignee $servicePrincipalId `
  --role "Contributor" `
  --scope "/subscriptions/$subscriptionId"

Write-Host "✅ Assigned Contributor role to service principal"

# Optional: Assign specific roles for your resource group after Terraform creates it
# az role assignment create --assignee $servicePrincipalId --role "Contributor" --scope "/subscriptions/$subscriptionId/resourceGroups/rg-todolist-dev"
```

### Step 3: Configure Federated Identity Credentials

#### Option A: For Main Branch Deployments

```powershell
# Create federated credential for main branch
$credentialJson = @{
    name = "TodoList-Main-Branch"
    issuer = "https://token.actions.githubusercontent.com"
    subject = "repo:$repoOwner/$repoName" + ":ref:refs/heads/main"
    description = "GitHub Actions main branch deployment"
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json

$credentialJson | Out-File -FilePath "credential-main.json" -Encoding UTF8

az ad app federated-credential create `
  --id $appObjectId `
  --parameters credential-main.json

Write-Host "✅ Created federated credential for main branch"
```

#### Option B: For Environment-based Deployments (Recommended)

```powershell
# Create federated credential for 'production' environment
$credentialJson = @{
    name = "TodoList-Production-Environment"
    issuer = "https://token.actions.githubusercontent.com"
    subject = "repo:$repoOwner/$repoName" + ":environment:production"
    description = "GitHub Actions production environment deployment"
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json

$credentialJson | Out-File -FilePath "credential-production.json" -Encoding UTF8

az ad app federated-credential create `
  --id $appObjectId `
  --parameters credential-production.json

Write-Host "✅ Created federated credential for production environment"

# Create federated credential for 'development' environment
$credentialDevJson = @{
    name = "TodoList-Development-Environment"
    issuer = "https://token.actions.githubusercontent.com"
    subject = "repo:$repoOwner/$repoName" + ":environment:development"
    description = "GitHub Actions development environment deployment"
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json

$credentialDevJson | Out-File -FilePath "credential-development.json" -Encoding UTF8

az ad app federated-credential create `
  --id $appObjectId `
  --parameters credential-development.json

Write-Host "✅ Created federated credential for development environment"
```

### Step 4: Configure GitHub Repository

#### Set GitHub Repository Variables

In your GitHub repository, go to `Settings` → `Secrets and variables` → `Actions`:

**Variables** (these are not sensitive):
```
AZURE_CLIENT_ID = [your-app-id-from-step-1]
AZURE_TENANT_ID = [your-tenant-id]
AZURE_SUBSCRIPTION_ID = [your-subscription-id]
```

**Secrets** (these are sensitive):
```
TF_VAR_postgres_admin_password = [secure-password-for-database]
```

#### PowerShell Commands to Get Values:

```powershell
Write-Host "=== GitHub Repository Configuration ==="
Write-Host "AZURE_CLIENT_ID: $appId"
Write-Host "AZURE_TENANT_ID: $tenantId"
Write-Host "AZURE_SUBSCRIPTION_ID: $subscriptionId"
Write-Host ""
Write-Host "Set these as Variables (not Secrets) in your GitHub repository:"
Write-Host "Settings → Secrets and variables → Actions → Variables"
Write-Host ""
Write-Host "Set this as a Secret:"
Write-Host "TF_VAR_postgres_admin_password: [generate-secure-password]"
```

### Step 5: Create GitHub Environments (Optional but Recommended)

If using environment-based federated credentials:

1. Go to your GitHub repository
2. Settings → Environments
3. Create environments: `production`, `development`
4. Configure protection rules as needed (require reviews, restrict branches, etc.)

### Step 6: Update GitHub Actions Workflow

Your workflow is already configured correctly! The key parts:

```yaml
permissions:
  id-token: write  # Required for OIDC token request
  contents: read   # Required for checkout

jobs:
  terraform:
    runs-on: ubuntu-latest
    environment: production  # If using environment-based credentials
    
    steps:
      - name: Azure Login via OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

## 🔧 Troubleshooting

### Common Issues

1. **"AADSTS70021: No matching federated identity record found"**
   - Check that the `subject` field in federated credential exactly matches your GitHub repository path
   - Verify the workflow is running in the correct environment/branch

2. **"id-token permission missing"**
   - Ensure your workflow has `permissions: id-token: write`

3. **"Federated credential not found"**
   - Verify the app registration has the correct federated credentials
   - Check that `AZURE_CLIENT_ID` matches the Application (client) ID

### Verification Commands

```powershell
# List federated credentials
az ad app federated-credential list --id $appObjectId

# Test Azure authentication (run in GitHub Actions)
az account show
```

## 🚀 Deployment Process

Once configured:

1. **Push to main branch** (or create PR to main)
2. **GitHub Actions automatically runs** with OIDC authentication
3. **Terraform provisions** Azure infrastructure
4. **Application deploys** to Azure Container Apps
5. **No secrets management needed** - everything is automated!

## 🛡️ Security Best Practices

1. **Use Environment Protection Rules**: Require approvals for production deployments
2. **Scope Permissions**: Use least-privilege Azure roles (not Contributor if possible)
3. **Monitor Access**: Enable Azure AD sign-in logs to track authentication
4. **Regular Audits**: Review federated credentials and remove unused ones
5. **Branch Protection**: Protect your main branch with required reviews

## 📊 Benefits Achieved

- ✅ **Zero secrets** stored in GitHub
- ✅ **Automatic token rotation**
- ✅ **Audit trail** of all authentication events
- ✅ **Environment-specific access control**
- ✅ **Compliance** with Zero Trust security principles

Your TodoList application now uses enterprise-grade, passwordless authentication! 🎉
