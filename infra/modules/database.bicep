targetScope = 'resourceGroup'

// =================
// PARAMETERS
// =================

@description('The name of the PostgreSQL server')
param serverName string

@description('The name of the database')
param databaseName string

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('PostgreSQL administrator username')
param administratorLogin string

@description('PostgreSQL administrator password')
@secure()
param administratorPassword string

@description('PostgreSQL server SKU')
param sku string = 'Standard_B1ms'

@description('PostgreSQL server tier')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param tier string = 'Burstable'

@description('Storage size in GB')
param storage int = 32

@description('The subnet ID for the PostgreSQL server')
param subnetId string

@description('Enable public network access to PostgreSQL')
param enablePublicAccess bool = false

@description('PostgreSQL version')
@allowed(['11', '12', '13', '14', '15', '16'])
param version string = '16'

@description('Backup retention days')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Enable geo-redundant backup')
param geoRedundantBackup bool = false

@description('Log Analytics workspace resource ID for diagnostic settings')
param logAnalyticsWorkspaceId string

// =================
// VARIABLES
// =================

var privateDnsZoneName = 'privatelink.postgres.database.azure.net'

// =================
// PRIVATE DNS ZONE
// =================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!enablePublicAccess) {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
  properties: {}
}

// Link the private DNS zone to the virtual network
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!enablePublicAccess) {
  parent: privateDnsZone
  name: '${serverName}-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: split(subnetId, '/subnets/')[0] // Extract VNet ID from subnet ID
    }
  }
}

// =================
// POSTGRESQL FLEXIBLE SERVER
// =================

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: sku
    tier: tier
  }
  properties: {
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    network: enablePublicAccess ? {
      publicNetworkAccess: 'Enabled'
    } : {
      publicNetworkAccess: 'Disabled'
      delegatedSubnetResourceId: subnetId
      privateDnsZoneArmResourceId: privateDnsZone.id
    }
    highAvailability: {
      mode: 'Disabled'
    }
    storage: {
      storageSizeGB: storage
      autoGrow: 'Enabled'
      tier: 'P10'
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup ? 'Enabled' : 'Disabled'
    }
    maintenanceWindow: {
      customWindow: 'Disabled'
      dayOfWeek: 0
      startHour: 0
      startMinute: 0
    }
  }
  dependsOn: [
    privateDnsZoneLink
  ]
}

// =================
// POSTGRESQL DATABASE
// =================

resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

// =================
// FIREWALL RULES (for public access only)
// =================

resource firewallRuleAllowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-06-01-preview' = if (enablePublicAccess) {
  parent: postgresServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// =================
// POSTGRESQL CONFIGURATIONS
// =================

// Enable SSL enforcement
resource sslConfiguration 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: postgresServer
  name: 'require_secure_transport'
  properties: {
    value: 'on'
    source: 'user-override'
  }
}

// Set timezone
resource timezoneConfiguration 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: postgresServer
  name: 'timezone'
  properties: {
    value: 'UTC'
    source: 'user-override'
  }
}

// Set log statement
resource logStatementConfiguration 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: postgresServer
  name: 'log_statement'
  properties: {
    value: 'none'
    source: 'user-override'
  }
}

// =================
// DIAGNOSTIC SETTINGS
// =================

resource postgresDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${serverName}-diagnostics'
  scope: postgresServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// =================
// OUTPUTS
// =================

@description('The resource ID of the PostgreSQL server')
output serverId string = postgresServer.id

@description('The name of the PostgreSQL server')
output serverName string = postgresServer.name

@description('The FQDN of the PostgreSQL server')
output fqdn string = postgresServer.properties.fullyQualifiedDomainName

@description('The name of the database')
output databaseName string = postgresDatabase.name

@description('The connection string template (without password)')
output connectionStringTemplate string = 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};Username=${administratorLogin};SSL Mode=Require;Trust Server Certificate=true'
