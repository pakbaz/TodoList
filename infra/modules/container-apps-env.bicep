targetScope = 'resourceGroup'

// =================
// PARAMETERS
// =================

@description('The name of the Container Apps environment')
param environmentName string

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('The resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string

@description('The subnet ID for the Container Apps environment')
param subnetId string

@description('Enable public network access to Container Apps environment')
param enablePublicAccess bool = true

@description('Enable zone redundancy')
param zoneRedundant bool = false

@description('Workload profiles for the environment')
param workloadProfiles array = [
  {
    name: 'Consumption'
    workloadProfileType: 'Consumption'
  }
]

// =================
// VARIABLES
// =================

var vnetConfiguration = enablePublicAccess ? null : {
  infrastructureSubnetId: subnetId
  internal: true
}

// =================
// CONTAINER APPS ENVIRONMENT
// =================

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    vnetConfiguration: vnetConfiguration
    zoneRedundant: zoneRedundant
    workloadProfiles: workloadProfiles
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey
      }
    }
  }
}

// =================
// DIAGNOSTIC SETTINGS
// =================

resource environmentDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environmentName}-diagnostics'
  scope: containerAppsEnvironment
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

@description('The resource ID of the Container Apps environment')
output environmentId string = containerAppsEnvironment.id

@description('The name of the Container Apps environment')
output environmentName string = containerAppsEnvironment.name

@description('The default domain of the Container Apps environment')
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain

@description('The static IP address of the Container Apps environment')
output staticIp string = containerAppsEnvironment.properties.staticIp

@description('Whether the environment is zone redundant')
output isZoneRedundant bool = containerAppsEnvironment.properties.zoneRedundant
