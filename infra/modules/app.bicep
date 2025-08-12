param location string
param env string
param skuName string
param skuTier string
param imageRepo string
param imageTag string
param connectionString string
param appInsightsConnectionString string
param tags object

var planName = toLower(uniqueString(resourceGroup().id, env, 'plan'))
var webAppName = toLower('todolist-${env}')

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  sku: {
    name: skuName
    tier: skuTier
    capacity: 1
  }
  tags: tags
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app,linux,container'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${imageRepo}:${imageTag}'
      alwaysOn: true
      appSettings: union([
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: toUpper(env)
        }
        {
          name: 'ConnectionStrings__DefaultConnection'
          value: connectionString
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
      ], empty(appInsightsConnectionString) ? [] : [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
      ])
    }
    httpsOnly: true
  }
}

output webAppName string = app.name
output planName string = plan.name
