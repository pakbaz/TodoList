@description('Key Vault name')
param keyVaultName string

@description('Azure region for resource deployment')
param location string

@description('Resource tags')
param tags object

@description('Subnet ID for private endpoint')
param subnetId string

@description('Virtual Network ID')
param vnetId string

@description('Environment name')
param environment string

// Key Vault configuration based on environment
var keyVaultConfig = {
  dev: {
    sku: 'standard'
    enableSoftDelete: true
    enablePurgeProtection: false
    softDeleteRetentionInDays: 7
  }
  staging: {
    sku: 'standard'
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 30
  }
  prod: {
    sku: 'premium'
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
  }
}

var selectedConfig = keyVaultConfig[environment]

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: selectedConfig.sku
    }
    tenantId: tenant().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: selectedConfig.enableSoftDelete
    enablePurgeProtection: selectedConfig.enablePurgeProtection
    softDeleteRetentionInDays: selectedConfig.softDeleteRetentionInDays
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// Private endpoint for Key Vault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${keyVaultName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-pe-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// Private DNS zone group for Key Vault private endpoint
resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

// Private DNS Zone for Key Vault (created in network module, referenced here)
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.vaultcore.azure.net'
}

// Diagnostic settings for Key Vault
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}

// Log Analytics Workspace (reference to existing workspace created in monitoring module)
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'law-todolist-${environment}-${substring(uniqueString(resourceGroup().id), 0, 6)}'
}

// Outputs
@description('Key Vault ID')
output keyVaultId string = keyVault.id

@description('Key Vault Name')
output keyVaultName string = keyVault.name

@description('Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri
