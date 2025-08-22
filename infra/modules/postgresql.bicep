@description('PostgreSQL Flexible Server name')
param postgresServerName string

@description('PostgreSQL database name')
param databaseName string

@description('Azure region for resource deployment')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

@description('Database subnet ID')
param databaseSubnetId string

@description('Private DNS Zone ID for PostgreSQL')
param privateDnsZoneId string

@description('Key Vault ID for storing secrets')
param keyVaultId string

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@secure()
@description('Administrator password for PostgreSQL server')
param administratorLoginPassword string

// PostgreSQL configuration based on environment
var postgresConfig = {
  dev: {
    skuName: 'Standard_B1ms'
    tier: 'Burstable'
    storageSizeGB: 32
    storageIops: 120
    version: '15'
    highAvailability: false
    backupRetentionDays: 7
    geoRedundantBackup: false
  }
  staging: {
    skuName: 'Standard_D2s_v3'
    tier: 'GeneralPurpose'
    storageSizeGB: 128
    storageIops: 500
    version: '15'
    highAvailability: false
    backupRetentionDays: 14
    geoRedundantBackup: true
  }
  prod: {
    skuName: 'Standard_D4s_v3'
    tier: 'GeneralPurpose'
    storageSizeGB: 256
    storageIops: 1000
    version: '15'
    highAvailability: true
    backupRetentionDays: 35
    geoRedundantBackup: true
  }
}

var selectedConfig = postgresConfig[environment]
var administratorLogin = 'todolistadmin'

// PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: postgresServerName
  location: location
  tags: tags
  sku: {
    name: selectedConfig.skuName
    tier: selectedConfig.tier
  }
  properties: {
    version: selectedConfig.version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
    storage: {
      storageSizeGB: selectedConfig.storageSizeGB
      iops: selectedConfig.storageIops
      tier: 'P4'
    }
    backup: {
      backupRetentionDays: selectedConfig.backupRetentionDays
      geoRedundantBackup: selectedConfig.geoRedundantBackup ? 'Enabled' : 'Disabled'
    }
    highAvailability: selectedConfig.highAvailability ? {
      mode: 'ZoneRedundant'
    } : {
      mode: 'Disabled'
    }
    maintenanceWindow: {
      customWindow: 'Enabled'
      dayOfWeek: 0
      startHour: 2
      startMinute: 0
    }
    network: {
      delegatedSubnetResourceId: databaseSubnetId
      privateDnsZoneArmResourceId: privateDnsZoneId
    }
  }
}

// Database
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// Firewall rules (none needed for private networking, but keeping for reference)
resource firewallRules 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-06-01-preview' = if (environment == 'dev') {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Diagnostic settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'postgres-diagnostics'
  scope: postgresServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

// Store connection string in Key Vault
resource connectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${last(split(keyVaultId, '/'))}/ConnectionStrings--DefaultConnection'
  properties: {
    value: 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};Username=${administratorLogin};Password=${administratorLoginPassword};SSL Mode=Require;Trust Server Certificate=true'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Store admin password in Key Vault
resource adminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${last(split(keyVaultId, '/'))}/PostgreSQL--AdminPassword'
  properties: {
    value: administratorLoginPassword
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Outputs
@description('PostgreSQL Flexible Server ID')
output postgresServerId string = postgresServer.id

@description('PostgreSQL Flexible Server Name')
output postgresServerName string = postgresServer.name

@description('PostgreSQL FQDN')
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName

@description('Database Name')
output databaseName string = database.name

@description('Administrator Login')
output administratorLogin string = administratorLogin

@description('Connection String Secret Name')
output connectionStringSecretName string = 'ConnectionStrings--DefaultConnection'

@description('Key Vault Secret Name for Database Credentials')
output databaseCredentialsKeyName string = 'PostgreSQL--AdminPassword'
