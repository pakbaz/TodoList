@description('The location for resources')
param location string

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('The application name')
param applicationName string

@description('Resource tags for cost tracking and governance')
param tags object = {}

@description('Log Analytics workspace ID')
param logAnalyticsWorkspaceId string

@description('Log Analytics workspace primary shared key')
@secure()
param logAnalyticsWorkspaceKey string

@description('Enable workload profiles')
param enableWorkloadProfiles bool = false

// Variables
var containerAppEnvironmentName = 'cae-${applicationName}-${environmentName}-${uniqueString(resourceGroup().id)}'

// Container Apps Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppEnvironmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: logAnalyticsWorkspaceKey
      }
    }
    workloadProfiles: enableWorkloadProfiles ? [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ] : null
    zoneRedundant: environmentName == 'prod'
  }
}

// Outputs
output environmentId string = containerAppEnvironment.id
output environmentName string = containerAppEnvironment.name
output defaultDomain string = containerAppEnvironment.properties.defaultDomain
output staticIp string = containerAppEnvironment.properties.staticIp
