@description('Location for PostgreSQL Flexible Server')
param location string

@description('Server name')
param name string

@description('Admin username (no @)')
@secure()
param adminUser string

@description('Admin password')
@secure()
param adminPassword string

@description('PostgreSQL version')
param version string = '16'

@description('Compute sku name, e.g., Standard_D2s_v3')
param skuName string = 'Standard_D2s_v3'

@description('Storage size in GiB')
param storageSizeGB int = 64

@description('Database name to create')
param databaseName string = 'todolistdb'

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: name
  location: location
  sku: {
    name: skuName
    tier: 'GeneralPurpose'
  }
  properties: {
    version: version
    administratorLogin: adminUser
    administratorLoginPassword: adminPassword
    highAvailability: {
      mode: 'Disabled'
    }
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
  }
}

resource firewall 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'AllowAllAzureIps'
  parent: server
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// Ensure application database exists
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  name: databaseName
  parent: server
}

output fqdn string = server.properties.fullyQualifiedDomainName
output serverId string = server.id
output dbName string = database.name
