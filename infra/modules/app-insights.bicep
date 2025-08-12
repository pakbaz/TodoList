// Application Insights module
targetScope = 'resourceGroup'

@description('The name of the Application Insights instance')
param appInsightsName string

@description('Location for the Application Insights instance')
param location string = resourceGroup().location

@description('Log Analytics workspace resource ID')
param workspaceResourceId string

@description('Tags to apply to the Application Insights instance')
param tags object = {}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Outputs
output appInsightsId string = applicationInsights.id
output appInsightsName string = applicationInsights.name
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
output connectionString string = applicationInsights.properties.ConnectionString
