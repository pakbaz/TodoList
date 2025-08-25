@description('Location for ACA environment')
param location string

@description('ACA environment name')
param name string

@description('Log Analytics workspace id')
param workspaceId string

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(workspaceId, '2022-10-01').customerId
        sharedKey: listKeys(workspaceId, '2022-10-01').primarySharedKey
      }
    }
  }
}

output environmentId string = env.id
