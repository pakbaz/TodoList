targetScope = 'resourceGroup'

// =================
// PARAMETERS
// =================

@description('The name of the Key Vault')
param keyVaultName string

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('The principal ID of the managed identity to grant access')
param managedIdentityPrincipalId string

@description('The subnet ID for the Key Vault private endpoint')
param subnetId string

@description('Enable public network access to Key Vault')
param enablePublicAccess bool = false

@description('Key Vault SKU')
@allowed(['standard', 'premium'])
param sku string = 'standard'

@description('Whether to create role assignments (requires User Access Administrator permissions)')
param createRoleAssignments bool = true

@description('The resource ID of the Log Analytics workspace for diagnostics')
param logAnalyticsWorkspaceId string = ''

// =================
// VARIABLES
// =================

var privateEndpointName = '${keyVaultName}-pe'
var privateDnsZoneName = 'privatelink.vaultcore.azure.net'
var privateDnsZoneGroupName = 'default'

// =================
// KEY VAULT
// =================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: sku
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    enableRbacAuthorization: true
    publicNetworkAccess: enablePublicAccess ? 'Enabled' : 'Disabled'
    networkAcls: enablePublicAccess ? {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    } : {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// =================
// ROLE ASSIGNMENTS
// =================

// Grant the managed identity access to Key Vault secrets
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments) {
  name: guid(keyVault.id, managedIdentityPrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// =================
// PRIVATE DNS ZONE
// =================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!enablePublicAccess) {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
  properties: {}
}

// Link the private DNS zone to the virtual network
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!enablePublicAccess) {
  parent: privateDnsZone
  name: '${keyVaultName}-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: split(subnetId, '/subnets/')[0] // Extract VNet ID from subnet ID
    }
  }
}

// =================
// PRIVATE ENDPOINT
// =================

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (!enablePublicAccess) {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
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

// Private DNS zone group for the private endpoint
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (!enablePublicAccess) {
  parent: privateEndpoint
  name: privateDnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vault'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// =================
// DIAGNOSTIC SETTINGS
// =================

resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// =================
// OUTPUTS
// =================

@description('The resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('The name of the Key Vault')
output keyVaultName string = keyVault.name

@description('The URI of the Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri

@description('The Key Vault resource reference for parent-child relationships')
output keyVaultReference object = {
  id: keyVault.id
  name: keyVault.name
  uri: keyVault.properties.vaultUri
}

@description('The resource ID of the private endpoint')
output privateEndpointId string = enablePublicAccess ? '' : privateEndpoint.id
