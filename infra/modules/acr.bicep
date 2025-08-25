@description('Location for ACR')
param location string

@description('ACR name (must be globally unique)')
param name string

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    publicNetworkAccess: 'Enabled'
  }
}

output loginServer string = registry.properties.loginServer
output registryId string = registry.id
