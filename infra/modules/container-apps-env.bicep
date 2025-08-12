// Container Apps Environment module
targetScope = 'resourceGroup'

@description('The name of the Container Apps Environment')
param environmentName string

@description('Location for the Container Apps Environment')
param location string = resourceGroup().location

@description('Log Analytics workspace ID')
param logAnalyticsWorkspaceId string

@description('Enable zone redundancy')
param zoneRedundant bool = false

@description('Tags to apply to the Container Apps Environment')
param tags object = {}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey
      }
    }
    zoneRedundant: zoneRedundant
  }
}

// Outputs
output environmentId string = containerAppsEnvironment.id
output environmentName string = containerAppsEnvironment.name
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
