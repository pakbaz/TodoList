@description('The location for resources')
param location string

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('The application name')
param applicationName string

@description('Resource tags for cost tracking and governance')
param tags object = {}

@description('Container Registry SKU')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Basic'

@description('Enable admin user')
param adminUserEnabled bool = false

@description('Public network access')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

// Variables
var registryName = 'cr${applicationName}${environmentName}${uniqueString(resourceGroup().id)}'

// Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess
    zoneRedundancy: sku == 'Premium' ? 'Enabled' : 'Disabled'
    policies: {
      quarantinePolicy: {
        status: 'Disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'Disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'Disabled'
      }
    }
    encryption: {
      status: 'Disabled'
    }
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
  }
}

// Outputs
output registryId string = containerRegistry.id
output registryName string = containerRegistry.name
output loginServer string = containerRegistry.properties.loginServer
