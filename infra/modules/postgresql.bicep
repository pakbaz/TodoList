// PostgreSQL Flexible Server module
targetScope = 'resourceGroup'

@description('The name of the PostgreSQL server')
param serverName string

@description('Location for the PostgreSQL server')
param location string = resourceGroup().location

@description('Administrator login for PostgreSQL server')
param administratorLogin string

@description('Administrator password for PostgreSQL server')
@secure()
param administratorPassword string

@description('PostgreSQL version')
@allowed(['11', '12', '13', '14', '15', '16'])
param postgresqlVersion string = '16'

@description('SKU name for the PostgreSQL server')
param skuName string = 'Standard_B1ms'

@description('Storage size in GB')
param storageSizeGB int = 32

@description('Enable high availability')
param enableHighAvailability bool = false

@description('Enable geo-redundant backup')
param enableGeoRedundantBackup bool = false

@description('Backup retention days')
param backupRetentionDays int = 7

@description('Tags to apply to the PostgreSQL server')
param tags object = {}

var tier = startsWith(skuName, 'Standard_B') ? 'Burstable' : (startsWith(skuName, 'Standard_D') ? 'GeneralPurpose' : 'MemoryOptimized')

resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: tier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    version: postgresqlVersion
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: enableGeoRedundantBackup ? 'Enabled' : 'Disabled'
    }
    highAvailability: enableHighAvailability ? {
      mode: 'ZoneRedundant'
    } : {
      mode: 'Disabled'
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
    }
  }
}

// Create database
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: postgresqlServer
  name: 'todolistdb'
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

// Configure firewall rule to allow Azure services
resource firewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = {
  parent: postgresqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Outputs
output serverId string = postgresqlServer.id
output serverName string = postgresqlServer.name
output serverFqdn string = postgresqlServer.properties.fullyQualifiedDomainName
output databaseName string = database.name
