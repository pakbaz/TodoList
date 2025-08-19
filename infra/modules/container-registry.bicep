targetScope = 'resourceGroup'

// =================
// PARAMETERS
// =================

@description('The name of the Azure Container Registry')
param acrName string

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('The principal ID of the managed identity to grant access')
param managedIdentityPrincipalId string

@description('The subnet ID for the ACR private endpoint')
param subnetId string

@description('Enable public network access to ACR')
param enablePublicAccess bool = false

@description('Whether to create role assignments (requires User Access Administrator permissions)')
param createRoleAssignments bool = true

@description('ACR SKU')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Basic'

// =================
// VARIABLES
// =================

var privateEndpointName = '${acrName}-pe'
var privateDnsZoneName = 'privatelink.azurecr.io'
var privateDnsZoneGroupName = 'default'

// =================
// CONTAINER REGISTRY
// =================

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false // Use managed identity instead
    policies: {
      quarantinePolicy: {
        status: 'enabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'enabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: enablePublicAccess ? 'Enabled' : 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: sku == 'Premium' ? 'Enabled' : 'Disabled'
  }
}

// =================
// ROLE ASSIGNMENTS
// =================

// Grant the managed identity ACR pull permissions
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments) {
  name: guid(acr.id, managedIdentityPrincipalId, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
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
  name: '${acrName}-dns-link'
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
          privateLinkServiceId: acr.id
          groupIds: [
            'registry'
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
        name: 'registry'
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

resource acrDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${acrName}-diagnostics'
  scope: acr
  properties: {
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

@description('The resource ID of the Azure Container Registry')
output acrId string = acr.id

@description('The name of the Azure Container Registry')
output acrName string = acr.name

@description('The login server of the Azure Container Registry')
output acrLoginServer string = acr.properties.loginServer

@description('The resource ID of the private endpoint')
output privateEndpointId string = enablePublicAccess ? '' : privateEndpoint.id
