@description('The location for resources')
param location string

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('The application name')
param applicationName string

@description('Resource tags for cost tracking and governance')
param tags object = {}

@description('Log Analytics workspace retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Log Analytics workspace SKU')
@allowed(['Free', 'Standard', 'Premium', 'Standalone', 'PerNode', 'PerGB2018', 'CapacityReservation'])
param sku string = 'PerGB2018'

// Variables
var workspaceName = 'log-${applicationName}-${environmentName}-${uniqueString(resourceGroup().id)}'

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Outputs
output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output customerId string = logAnalyticsWorkspace.properties.customerId
@secure()
output primarySharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey
