param location string
param env string
param tags object
@secure()
param postgresAdminPassword string

var kvName = toLower(uniqueString(resourceGroup().id, env, 'kv'))

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    enableSoftDelete: true
    enablePurgeProtection: false
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
  }
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(postgresAdminPassword)) {
  parent: kv
  name: 'pgAdminPassword'
  properties: {
    value: postgresAdminPassword
  }
}

output keyVaultName string = kv.name
