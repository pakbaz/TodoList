@description('Location for Application Insights')
param location string

@description('App Insights name')
param name string

@description('Connected Log Analytics workspace id')
param workspaceId string

@description('Application type (web)')
param appType string = 'web'

resource insights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: appType
  properties: {
    Application_Type: appType
    WorkspaceResourceId: workspaceId
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
  }
}

output instrumentationKey string = insights.properties.InstrumentationKey
output connectionString string = insights.properties.ConnectionString
