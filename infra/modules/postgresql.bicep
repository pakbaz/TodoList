@description('The location for resources')
param location string

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('The application name')
param applicationName string

@description('Resource tags for cost tracking and governance')
param tags object = {}

@description('PostgreSQL server administrator login')
param administratorLogin string = 'todolistadmin'

@description('PostgreSQL server administrator password')
@secure()
param administratorPassword string

@description('PostgreSQL server SKU')
param skuName string = environmentName == 'prod' ? 'Standard_B2s' : 'Standard_B1ms'

@description('PostgreSQL server storage size in GB')
@minValue(32)
@maxValue(32768)
param storageSizeGB int = environmentName == 'prod' ? 128 : 32

@description('Database name')
param databaseName string = 'todolistdb'

@description('Enable high availability')
param enableHighAvailability bool = environmentName == 'prod'

@description('Backup retention days')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = environmentName == 'prod' ? 14 : 7

@description('Key Vault ID for storing connection string')
param keyVaultId string

// Variables
var serverName = 'psql-${applicationName}-${environmentName}-${uniqueString(resourceGroup().id)}'
var keyVaultName = last(split(keyVaultId, '/'))

// PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    version: '15'
    storage: {
      storageSizeGB: storageSizeGB
      iops: 120
      tier: 'P4'
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: enableHighAvailability ? {
      mode: 'ZoneRedundant'
    } : {
      mode: 'Disabled'
    }
    maintenanceWindow: {
      customWindow: 'Disabled'
      dayOfWeek: 0
      startHour: 0
      startMinute: 0
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: tenant().tenantId
    }
    dataEncryption: {
      type: 'SystemManaged'
    }
  }
}

// Configure firewall rules to allow Azure services
resource postgresFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = {
  name: 'AllowAzureServices'
  parent: postgresServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Create the database
resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  name: databaseName
  parent: postgresServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

// Reference existing Key Vault
resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Store connection string in Key Vault
resource connectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'postgresql-connection-string'
  parent: existingKeyVault
  properties: {
    value: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Port=5432;Database=${databaseName};Username=${administratorLogin};Password=${administratorPassword};SSL Mode=Require;'
  }
}

// Store passwordless connection string in Key Vault (for managed identity)
resource passwordlessConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'postgresql-passwordless-connection-string'
  parent: existingKeyVault
  properties: {
    value: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Port=5432;Database=${databaseName};'
  }
}

// Outputs
output serverId string = postgresServer.id
output serverName string = postgresServer.name
output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName
output databaseName string = databaseName
