// Container Registry module
targetScope = 'resourceGroup'

@description('The name of the Container Registry')
param registryName string

@description('Location for the Container Registry')
param location string = resourceGroup().location

@description('Tags to apply to the Container Registry')
param tags object = {}

@description('SKU for the Container Registry')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Standard'

@description('Enable admin user for the Container Registry')
param adminUserEnabled bool = true

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    anonymousPullEnabled: false
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: sku == 'Premium' ? 'Enabled' : 'Disabled'
  }
}

// Outputs
output registryId string = containerRegistry.id
output registryName string = containerRegistry.name
output registryServer string = containerRegistry.properties.loginServer
