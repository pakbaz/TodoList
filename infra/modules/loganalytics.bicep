@description('Location for Log Analytics workspace')
param location string

@description('Workspace name')
param name string

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
  }
}

output workspaceId string = workspace.id
output customerId string = workspace.properties.customerId
