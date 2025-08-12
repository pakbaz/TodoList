// Log Analytics Workspace module
targetScope = 'resourceGroup'

@description('The name of the Log Analytics workspace')
param workspaceName string

@description('Location for the Log Analytics workspace')
param location string = resourceGroup().location

@description('Retention in days for Log Analytics workspace')
param retentionInDays int = 30

@description('Tags to apply to the Log Analytics workspace')
param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Outputs
output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output customerId string = logAnalyticsWorkspace.properties.customerId
