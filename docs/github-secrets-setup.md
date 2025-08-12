# 🔧 GitHub Secrets Setup Guide

## 🎯 Current Issue
Your GitHub Actions workflow is failing with:
```
Error: Login failed with Error: Using auth-type: SERVICE_PRINCIPAL. 
Not all values are present. Ensure 'client-id' and 'tenant-id' are supplied.
```

This is **expected behavior** - the workflow needs Azure authentication secrets to be configured.

## 🚀 Solution: Configure GitHub Secrets

### Step 1: Create Azure Service Principal with OIDC

Run these commands in your terminal:

```bash
# 1. Login to Azure (if not already logged in)
az login

# 2. Get your subscription ID
az account show --query id --output tsv

# 3. Create Service Principal for GitHub Actions
az ad sp create-for-rbac \
  --name "TodoList-GitHub-Actions" \
  --role "Contributor" \
  --scopes "/subscriptions/$(az account show --query id --output tsv)" \
  --json-auth

# 4. Save the output - you'll need the clientId and tenantId
```

The output will look like:
```json
{
  "clientId": "12345678-1234-1234-1234-123456789012",
  "clientSecret": "xxxxx~xxxxx",
  "subscriptionId": "87654321-4321-4321-4321-210987654321",
  "tenantId": "11111111-1111-1111-1111-111111111111"
}
```

### Step 2: Configure OIDC Federation

```bash
# Replace YOUR_CLIENT_ID with the clientId from step 1
export CLIENT_ID="12345678-1234-1234-1234-123456789012"

# Create OIDC federated credential for main branch
az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters '{
    "name": "TodoList-GitHub-Main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:pakbaz/TodoList:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create OIDC federated credential for pull requests  
az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters '{
    "name": "TodoList-GitHub-PR",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:pakbaz/TodoList:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create OIDC federated credentials for GitHub environments
az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters '{
    "name": "TodoList-GitHub-Environment-Dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:pakbaz/TodoList:environment:dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'

az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters '{
    "name": "TodoList-GitHub-Environment-Staging",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:pakbaz/TodoList:environment:staging",
    "audiences": ["api://AzureADTokenExchange"]
  }'

az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters '{
    "name": "TodoList-GitHub-Environment-Prod",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:pakbaz/TodoList:environment:prod",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Verify the federated credentials were created
az ad app federated-credential list --id $CLIENT_ID --query '[].{Name:name, Subject:subject}' --output table
```### Step 3: Add GitHub Secrets

Navigate to: https://github.com/pakbaz/TodoList/settings/secrets/actions

Click "New repository secret" and add these 4 secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AZURE_CLIENT_ID` | `12345678-1234-1234-1234-123456789012` | From Service Principal output |
| `AZURE_TENANT_ID` | `11111111-1111-1111-1111-111111111111` | From Service Principal output |
| `AZURE_SUBSCRIPTION_ID` | `87654321-4321-4321-4321-210987654321` | From Service Principal output |
| `POSTGRES_ADMIN_PASSWORD` | `YourSecurePassword123!` | Strong password for PostgreSQL admin |

### Step 4: Verify Permissions

Ensure the Service Principal has the required permissions:

```bash
# Check role assignments
az role assignment list \
  --assignee $CLIENT_ID \
  --query '[].{Role:roleDefinitionName, Scope:scope}' \
  --output table

# If no Contributor role, add it:
az role assignment create \
  --assignee $CLIENT_ID \
  --role "Contributor" \
  --scope "/subscriptions/$(az account show --query id --output tsv)"
```

## 🧪 Test the Configuration

### Option 1: Trigger Workflow
Push any small change to trigger the workflow:

```bash
cd /Users/pakbaz/code/TodoList
echo "# Trigger deployment" >> README.md
git add README.md
git commit -m "test: trigger workflow after GitHub secrets configuration"
git push
```

### Option 2: Manual Trigger
Go to: https://github.com/pakbaz/TodoList/actions/workflows/deploy.yml
Click "Run workflow" → "Run workflow"

## 🔍 Expected Results

After configuring the secrets, your workflow should:

1. ✅ **Azure Login**: Successfully authenticate with Azure
2. ✅ **Resource Group Creation**: Create todolist-dev-rg, todolist-staging-rg, todolist-prod-rg
3. ✅ **Infrastructure Deployment**: Deploy all Bicep templates
4. ✅ **Container Build**: Build and push Docker image
5. ✅ **Application Deployment**: Deploy to Container Apps
6. ✅ **Health Checks**: Verify application is running

## 🚨 Troubleshooting

### Common Issues:

**Issue 1: Still getting authentication error**
- Verify all 4 secrets are configured correctly
- Check secret names match exactly (case-sensitive)
- Ensure OIDC federation is configured for the correct repository

**Issue 2: Permission denied**
```bash
# Grant additional permissions if needed
az role assignment create \
  --assignee $CLIENT_ID \
  --role "User Access Administrator" \
  --scope "/subscriptions/$(az account show --query id --output tsv)"
```

**Issue 3: Resource already exists**
- The workflow will handle existing resources gracefully
- Bicep templates are idempotent (safe to re-run)

### Debug Commands:
```bash
# Check if secrets are configured (will show asterisks if set)
gh secret list --repo pakbaz/TodoList

# View workflow logs
gh run list --repo pakbaz/TodoList --limit 5
gh run view --repo pakbaz/TodoList [RUN_ID] --log
```

## 🎯 Quick Setup Commands

Here's a condensed version for quick setup:

```bash
# 1. Create Service Principal and get values
SP_OUTPUT=$(az ad sp create-for-rbac --name "TodoList-GitHub-Actions" --role "Contributor" --scopes "/subscriptions/$(az account show --query id --output tsv)" --json-auth)
CLIENT_ID=$(echo $SP_OUTPUT | jq -r '.clientId')
TENANT_ID=$(echo $SP_OUTPUT | jq -r '.tenantId')
SUBSCRIPTION_ID=$(echo $SP_OUTPUT | jq -r '.subscriptionId')

echo "Client ID: $CLIENT_ID"
echo "Tenant ID: $TENANT_ID" 
echo "Subscription ID: $SUBSCRIPTION_ID"

# 2. Configure OIDC Federation (CRITICAL - this was missing!)
az ad app federated-credential create --id $CLIENT_ID --parameters '{
  "name": "TodoList-GitHub-Main",
  "issuer": "https://token.actions.githubusercontent.com", 
  "subject": "repo:pakbaz/TodoList:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id $CLIENT_ID --parameters '{
  "name": "TodoList-GitHub-PR", 
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:pakbaz/TodoList:pull_request", 
  "audiences": ["api://AzureADTokenExchange"]
}'

# 3. Verify OIDC credentials were created
echo "Verifying OIDC federated credentials:"
az ad app federated-credential list --id $CLIENT_ID --query '[].{Name:name, Subject:subject}' --output table

# 4. Set GitHub secrets (requires gh CLI)
gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID" --repo pakbaz/TodoList
gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --repo pakbaz/TodoList  
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --repo pakbaz/TodoList
gh secret set POSTGRES_ADMIN_PASSWORD --body "SecureP@ssw0rd123!" --repo pakbaz/TodoList

# 5. Trigger deployment
echo "# OIDC configured - ready for deployment $(date)" >> README.md
git add README.md && git commit -m "feat: configure OIDC federation for Azure authentication" && git push
```

## 🆘 **URGENT FIX NEEDED**

The error you're seeing indicates that **OIDC federated credentials are NOT configured**. You need to run these commands immediately:

```bash
# Get your existing Service Principal Client ID
# Replace with the actual CLIENT_ID from your GitHub secrets
CLIENT_ID="YOUR_ACTUAL_CLIENT_ID_HERE"

# Create the missing OIDC federated credentials
az ad app federated-credential create --id $CLIENT_ID --parameters '{
  "name": "TodoList-GitHub-Main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:pakbaz/TodoList:ref:refs/heads/main", 
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id $CLIENT_ID --parameters '{
  "name": "TodoList-GitHub-PR",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:pakbaz/TodoList:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Verify they were created
az ad app federated-credential list --id $CLIENT_ID
```

## ✅ Success Indicators

Once configured correctly, you should see:
- ✅ GitHub Actions workflow completes successfully
- ✅ Azure resources appear in your subscription
- ✅ TodoList application accessible via Container App URL
- ✅ Application Insights showing telemetry data

The first deployment typically takes 5-10 minutes to complete all resources.

---

**Need help?** Check the GitHub Actions logs at: https://github.com/pakbaz/TodoList/actions
