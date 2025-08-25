@description('Location for Key Vault')
param location string

@description('Key Vault name')
param name string

@description('Enable RBAC instead of access policies')
param enableRbac bool = true

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  properties: {
    enableRbacAuthorization: enableRbac
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    publicNetworkAccess: 'Enabled'
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false
  }
}

output vaultId string = vault.id
output vaultName string = vault.name
