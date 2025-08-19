# Role Assignment Permissions Setup

## Issue
The Azure deployment may fail with role assignment permission errors like:
```
Authorization failed for template resource 'xxx' of type 'Microsoft.Authorization/roleAssignments'. 
The client 'xxx' with object id 'xxx' does not have permission to perform action 
'Microsoft.Authorization/roleAssignments/write' at scope '...'
```

## Root Cause
The GitHub Actions service principal (used for OIDC authentication) doesn't have sufficient permissions to assign roles to Azure resources. Role assignment requires the "User Access Administrator" role.

## Solutions

### Option 1: Grant Additional Permissions (Recommended for Production)

1. **Find your GitHub Actions App Registration:**
   ```bash
   az ad app list --display-name "your-github-app-name" --query "[].{appId:appId, displayName:displayName}"
   ```

2. **Get the Service Principal Object ID:**
   ```bash
   az ad sp list --display-name "your-github-app-name" --query "[].{objectId:id, displayName:displayName}"
   ```

3. **Assign User Access Administrator role at Resource Group level:**
   ```bash
   az role assignment create \
     --assignee <service-principal-object-id> \
     --role "User Access Administrator" \
     --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>"
   ```

4. **Deploy with role assignments enabled:**
   ```bash
   az deployment group create \
     --resource-group rg-todolist-prod \
     --template-file infra/main.bicep \
     --parameters infra/parameters/prod.bicepparam \
     --parameters createRoleAssignments=true
   ```

### Option 2: Deploy Without Role Assignments (Quick Fix)

The infrastructure is deployed with `createRoleAssignments=false` by default. This means:
- ✅ All Azure resources are created successfully
- ❌ The Container App won't be able to access Key Vault secrets
- ❌ The Container App won't be able to pull images from ACR privately

You'll need to manually assign roles after deployment:

1. **Get the Managed Identity Principal ID:**
   ```bash
   PRINCIPAL_ID=$(az identity show \
     --resource-group rg-todolist-prod \
     --name todolist-identity-prod-$(echo $RANDOM) \
     --query principalId -o tsv)
   ```

2. **Assign Key Vault Secrets User role:**
   ```bash
   az role assignment create \
     --assignee $PRINCIPAL_ID \
     --role "Key Vault Secrets User" \
     --scope "/subscriptions/<subscription>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
   ```

3. **Assign ACR Pull role:**
   ```bash
   az role assignment create \
     --assignee $PRINCIPAL_ID \
     --role "AcrPull" \
     --scope "/subscriptions/<subscription>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr-name>"
   ```

## Security Considerations

- **User Access Administrator** is a privileged role that allows managing access to Azure resources
- Only grant this permission to trusted service principals
- Consider using separate service principals for different environments
- For production, implement proper RBAC governance and approval processes

## Testing

After setting up permissions, test the deployment:

```bash
# Full deployment with role assignments
az deployment group create \
  --resource-group rg-todolist-prod \
  --template-file infra/main.bicep \
  --parameters infra/parameters/prod.bicepparam \
  --parameters createRoleAssignments=true \
  --parameters imageTag=latest \
  --parameters databaseAdminPassword="$(openssl rand -base64 32)"
```

## Alternative Approaches

### Using Azure CLI with Personal Account
If you're deploying manually, you can use your personal Azure CLI login which typically has broader permissions:

```bash
az login
az account set --subscription <subscription-id>
# Deploy normally - your personal account likely has required permissions
```

### Using Managed Identity in Azure DevOps
Azure DevOps pipelines can use managed identities with pre-configured permissions.

### Using Azure Resource Manager Service Connections
Configure service connections in Azure DevOps with proper role assignments.
