// Key Vault Secrets module
targetScope = 'resourceGroup'

@description('The name of the Key Vault')
param keyVaultName string

@description('Array of secrets to store in Key Vault')
param secrets array

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource keyVaultSecrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [for secret in secrets: {
  parent: keyVault
  name: secret.name
  properties: {
    value: secret.value
    contentType: 'text/plain'
  }
}]

// Outputs
output secretNames array = [for secret in secrets: secret.name]
