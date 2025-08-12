@description('Location')
param location string
@description('Environment')
param env string
@description('Admin user')
param adminUser string
@secure()
param adminPassword string
@description('SKU name (e.g., B_Standard_B1ms)')
param skuName string = 'B_Standard_B1ms'
@description('Tags object')
param tags object

var serverName = toLower(uniqueString(resourceGroup().id, env, 'pg'))
var dbName = 'todolist'

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: adminUser
    administratorLoginPassword: adminPassword
    version: '16'
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      // Using defaults; public access enabled by default for dev
    }
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  parent: server
  name: dbName
  properties: {}
}

output serverName string = server.name
output host string = '${server.name}.postgres.database.azure.com'
output databaseName string = dbName
