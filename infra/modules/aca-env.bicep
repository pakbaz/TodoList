@description('Azure Container Apps Environment for hosting container applications')

param name string
param location string = resourceGroup().location
param tags object = {}

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Enable Dapr for the environment')
@secure()
param daprAIInstrumentationKey string = ''

@description('Environment type - Consumption or WorkloadProfiles')
@allowed(['Consumption', 'WorkloadProfiles'])
param environmentType string = 'Consumption'

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
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
    daprAIInstrumentationKey: !empty(daprAIInstrumentationKey) ? daprAIInstrumentationKey : null
    workloadProfiles: environmentType == 'WorkloadProfiles' ? [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ] : null
  }
}

// Outputs
output id string = containerAppsEnvironment.id
output name string = containerAppsEnvironment.name
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output staticIp string = containerAppsEnvironment.properties.staticIp
