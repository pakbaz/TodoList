targetScope = 'resourceGroup'

// =================
// PARAMETERS
// =================

@description('The name of the application')
param appName string = 'todolist'

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('The container image tag to deploy')
param imageTag string = 'latest'

@description('The name of the container registry')
param acrName string = '${appName}${environment}${uniqueString(resourceGroup().id)}'

@description('Database administrator username')
param databaseAdminUsername string = 'dbadmin'

@description('Database administrator password')
@secure()
param databaseAdminPassword string

@description('Whether to create role assignments (requires User Access Administrator permissions)')
param createRoleAssignments bool = false

@description('Tags to apply to all resources')
param tags object = {
  Application: appName
  Environment: environment
  ManagedBy: 'Bicep'
  DeployedAt: utcNow()
}

// =================
// VARIABLES
// =================

var resourceNameSuffix = '${environment}-${uniqueString(resourceGroup().id)}'
var managedIdentityName = '${appName}-identity-${resourceNameSuffix}'
var keyVaultName = '${appName}-kv-${substring(uniqueString(resourceGroup().id), 0, 8)}'
var logAnalyticsName = '${appName}-logs-${resourceNameSuffix}'
var appInsightsName = '${appName}-ai-${resourceNameSuffix}'
var containerAppsEnvName = '${appName}-env-${resourceNameSuffix}'
var containerAppName = '${appName}-app-${resourceNameSuffix}'
var vnetName = '${appName}-vnet-${resourceNameSuffix}'
var dbServerName = '${appName}-db-${resourceNameSuffix}'
var dbName = '${appName}db'

// Environment-specific configuration
var environmentConfig = {
  dev: {
    containerApp: {
      minReplicas: 0
      maxReplicas: 2
      cpu: '0.25'
      memory: '0.5Gi'
    }
    database: {
      sku: 'Standard_B1ms'
      tier: 'Burstable'
      storage: 32
    }
    enablePublicAccess: true
  }
  staging: {
    containerApp: {
      minReplicas: 1
      maxReplicas: 5
      cpu: '0.5'
      memory: '1Gi'
    }
    database: {
      sku: 'Standard_D2s_v3'
      tier: 'GeneralPurpose'
      storage: 128
    }
    enablePublicAccess: true
  }
  prod: {
    containerApp: {
      minReplicas: 2
      maxReplicas: 10
      cpu: '1'
      memory: '2Gi'
    }
    database: {
      sku: 'Standard_E2s_v3'
      tier: 'MemoryOptimized'
      storage: 128
    }
    enablePublicAccess: true
  }
}

// =================
// MANAGED IDENTITY
// =================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

// =================
// NETWORKING
// =================

module networking 'modules/networking.bicep' = {
  name: 'networking-${deployment().name}'
  params: {
    vnetName: vnetName
    location: location
    tags: tags
    environment: environment
  }
}

// =================
// LOG ANALYTICS & MONITORING
// =================

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'logAnalytics-${deployment().name}'
  params: {
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
    location: location
    tags: tags
  }
}

// =================
// KEY VAULT
// =================

module keyVault 'modules/key-vault.bicep' = {
  name: 'keyVault-${deployment().name}'
  params: {
    keyVaultName: keyVaultName
    location: location
    tags: tags
    managedIdentityPrincipalId: managedIdentity.properties.principalId
    subnetId: networking.outputs.keyVaultSubnetId
    enablePublicAccess: environmentConfig[environment].enablePublicAccess
    createRoleAssignments: createRoleAssignments
  }
}

// =================
// CONTAINER REGISTRY
// =================

module containerRegistry 'modules/container-registry.bicep' = {
  name: 'containerRegistry-${deployment().name}'
  params: {
    acrName: acrName
    location: location
    tags: tags
    managedIdentityPrincipalId: managedIdentity.properties.principalId
    subnetId: networking.outputs.acrSubnetId
    enablePublicAccess: environmentConfig[environment].enablePublicAccess
    createRoleAssignments: createRoleAssignments
  }
}

// =================
// DATABASE
// =================

module database 'modules/database.bicep' = {
  name: 'database-${deployment().name}'
  params: {
    serverName: dbServerName
    databaseName: dbName
    location: location
    tags: tags
    administratorLogin: databaseAdminUsername
    administratorPassword: databaseAdminPassword
    sku: environmentConfig[environment].database.sku
    tier: environmentConfig[environment].database.tier
    storage: environmentConfig[environment].database.storage
    subnetId: networking.outputs.databaseSubnetId
    enablePublicAccess: environmentConfig[environment].enablePublicAccess
  }
}

// Get Key Vault reference for secret creation
resource keyVaultReference 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
  dependsOn: [
    keyVault
  ]
}

// Store database connection string in Key Vault
resource dbConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVaultReference
  name: 'ConnectionStrings--DefaultConnection'
  properties: {
    value: 'Host=${database.outputs.fqdn};Database=${dbName};Username=${databaseAdminUsername};Password=${databaseAdminPassword};SSL Mode=Require;Trust Server Certificate=true'
  }
}

// =================
// CONTAINER APPS ENVIRONMENT
// =================

module containerAppsEnvironment 'modules/container-apps-env.bicep' = {
  name: 'containerAppsEnv-${deployment().name}'
  params: {
    environmentName: containerAppsEnvName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
    subnetId: networking.outputs.containerAppsSubnetId
    enablePublicAccess: environmentConfig[environment].enablePublicAccess
  }
}

// =================
// CONTAINER APP
// =================

module containerApp 'modules/container-app.bicep' = {
  name: 'containerApp-${deployment().name}'
  params: {
    containerAppName: containerAppName
    location: location
    tags: tags
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.environmentId
    managedIdentityId: managedIdentity.id
    acrName: containerRegistry.outputs.acrName
    imageTag: imageTag
    appName: appName
    minReplicas: environmentConfig[environment].containerApp.minReplicas
    maxReplicas: environmentConfig[environment].containerApp.maxReplicas
    cpu: environmentConfig[environment].containerApp.cpu
    memory: environmentConfig[environment].containerApp.memory
    keyVaultName: keyVault.outputs.keyVaultName
    appInsightsConnectionString: logAnalytics.outputs.appInsightsConnectionString
  }
}

// =================
// OUTPUTS
// =================

@description('The name of the deployed container app')
output containerAppName string = containerApp.outputs.containerAppName

@description('The FQDN of the container app')
output containerAppFqdn string = containerApp.outputs.containerAppFqdn

@description('The name of the container registry')
output acrName string = containerRegistry.outputs.acrName

@description('The name of the managed identity')
output managedIdentityName string = managedIdentity.name

@description('The name of the Key Vault')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('The database server FQDN')
output databaseFqdn string = database.outputs.fqdn

@description('The container apps environment name')
output containerAppsEnvironmentName string = containerAppsEnvironment.outputs.environmentName
