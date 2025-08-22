@description('Key Vault name')
param keyVaultName string

@description('Managed Identity ID for role assignments')
param managedIdentityId string

@description('Managed Identity Principal ID for role assignments')
param managedIdentityPrincipalId string

@description('PostgreSQL Server admin password')
@secure()
param postgresAdminPassword string

@description('Application Insights Connection String')
@secure()
param appInsightsConnectionString string

@description('PostgreSQL connection string')
@secure()
param postgresConnectionString string

@description('Environment name')
param environment string

// Get reference to existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Store PostgreSQL admin password
resource postgresPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'PostgreSQL--AdminPassword'
  properties: {
    value: postgresAdminPassword
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Store PostgreSQL connection string
resource connectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ConnectionStrings--DefaultConnection'
  properties: {
    value: postgresConnectionString
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Store Application Insights connection string
resource appInsightsSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ApplicationInsights--ConnectionString'
  properties: {
    value: appInsightsConnectionString
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// JWT signing key for environment
resource jwtSigningKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'JWT--SigningKey'
  properties: {
    value: base64(guid(subscription().subscriptionId, resourceGroup().id, environment))
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Application encryption key
resource encryptionKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'Application--EncryptionKey'
  properties: {
    value: base64(guid(subscription().subscriptionId, keyVault.id, environment))
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Role assignment: Key Vault Secrets User for managed identity
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentityId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Key Vault Certificate User for managed identity
resource keyVaultCertificateUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentityId, 'Key Vault Certificate User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
@description('PostgreSQL Credentials Key Vault Reference')
output postgresCredentialsUri string = postgresPasswordSecret.properties.secretUri

@description('Database Connection Key Vault Reference')
output databaseConnectionUri string = connectionStringSecret.properties.secretUri

@description('Application Insights Key Vault Reference')
output appInsightsKeyVaultUri string = appInsightsSecret.properties.secretUri

@description('JWT Key Vault Reference')
output jwtKeyVaultUri string = jwtSigningKeySecret.properties.secretUri

@description('Encryption Key Vault Reference')
output encryptionKeyVaultUri string = encryptionKeySecret.properties.secretUri

@description('Key Vault Secrets User Role Assignment ID')
output keyVaultSecretsUserRoleId string = keyVaultSecretsUserRole.id

@description('Key Vault Certificate User Role Assignment ID')
output keyVaultCertificateUserRoleId string = keyVaultCertificateUserRole.id
