@description('Container Registry name')
param containerRegistryName string

@description('Azure region for resource deployment')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

@description('Virtual Network ID for private endpoint')
param vnetId string

@description('Private endpoint subnet ID')
param privateEndpointSubnetId string

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

// Container Registry configuration based on environment
var acrConfig = {
  dev: {
    sku: 'Basic'
    publicNetworkAccess: 'Enabled'
    adminUserEnabled: true
    anonymousPullEnabled: false
    retentionDays: 7
  }
  staging: {
    sku: 'Standard'
    publicNetworkAccess: 'Disabled'
    adminUserEnabled: false
    anonymousPullEnabled: false
    retentionDays: 30
  }
  prod: {
    sku: 'Premium'
    publicNetworkAccess: 'Disabled'
    adminUserEnabled: false
    anonymousPullEnabled: false
    retentionDays: 90
  }
}

var selectedConfig = acrConfig[environment]

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: containerRegistryName
  location: location
  tags: tags
  sku: {
    name: selectedConfig.sku
  }
  properties: {
    adminUserEnabled: selectedConfig.adminUserEnabled
    publicNetworkAccess: selectedConfig.publicNetworkAccess
    anonymousPullEnabled: selectedConfig.anonymousPullEnabled
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      retentionPolicy: {
        status: 'enabled'
        days: selectedConfig.retentionDays
      }
      trustPolicy: {
        status: environment == 'prod' ? 'enabled' : 'disabled'
        type: 'Notary'
      }
      quarantinePolicy: {
        status: environment == 'prod' ? 'enabled' : 'disabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: selectedConfig.sku == 'Premium'
    networkRuleSet: {
      defaultAction: selectedConfig.publicNetworkAccess == 'Disabled' ? 'Deny' : 'Allow'
      ipRules: []
    }
  }
}

// Private endpoint for ACR (Premium SKU only)
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (selectedConfig.sku == 'Premium') {
  name: 'pe-${containerRegistryName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'acr-connection'
        properties: {
          privateLinkServiceId: containerRegistry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group for ACR
resource acrPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (selectedConfig.sku == 'Premium') {
  parent: acrPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'acr-config'
        properties: {
          privateDnsZoneId: acrPrivateDnsZone.id
        }
      }
    ]
  }
}

// Private DNS Zone for ACR
resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (selectedConfig.sku == 'Premium') {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to VNet
resource acrPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (selectedConfig.sku == 'Premium') {
  parent: acrPrivateDnsZone
  name: 'acr-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// Diagnostic settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'acr-diagnostics'
  scope: containerRegistry
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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
  }
}

// Task for automated image builds (Premium SKU only) - Simplified without source control auth
resource buildTask 'Microsoft.ContainerRegistry/registries/tasks@2019-06-01-preview' = if (selectedConfig.sku == 'Premium') {
  parent: containerRegistry
  name: 'todolist-build-task'
  location: location
  properties: {
    status: 'Disabled' // Will be enabled after manual configuration
    platform: {
      os: 'Linux'
      architecture: 'amd64'
    }
    agentConfiguration: {
      cpu: 2
    }
    step: {
      type: 'Docker'
      dockerFilePath: 'Dockerfile'
      contextPath: '.'
      imageNames: [
        '${containerRegistry.properties.loginServer}/todolist:{{.Run.ID}}'
        '${containerRegistry.properties.loginServer}/todolist:latest'
      ]
      isPushEnabled: true
      noCache: false
    }
  }
}

// Outputs
@description('Container Registry ID')
output containerRegistryId string = containerRegistry.id

@description('Container Registry Name')
output containerRegistryName string = containerRegistry.name

@description('Container Registry Login Server')
output containerRegistryLoginServer string = containerRegistry.properties.loginServer

@description('Container Registry Resource ID')
output containerRegistryResourceId string = containerRegistry.id

@description('Private DNS Zone ID for ACR')
output acrPrivateDnsZoneId string = selectedConfig.sku == 'Premium' ? acrPrivateDnsZone.id : ''

@description('ACR Admin Enabled')
output adminUserEnabled bool = selectedConfig.adminUserEnabled
