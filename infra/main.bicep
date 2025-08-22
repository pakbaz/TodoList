targetScope = 'subscription'

@description('The location for all resources')
param location string = 'eastus2'

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('The application name')
@minLength(2)
@maxLength(20)
param applicationName string = 'todolist'

@description('PostgreSQL administrator login')
param postgresAdminLogin string = 'todolistadmin'

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('Object ID of the deployment principal')
param deploymentPrincipalId string

// Common tags for all resources
var commonTags = {
  Environment: environmentName
  Application: applicationName
  ManagedBy: 'Infrastructure as Code'
  Project: 'TodoList'
}

// Create Resource Group at subscription scope
var resourceGroupName = 'rg-${applicationName}-${environmentName}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: commonTags
}

// Log Analytics Workspace
module logAnalyticsModule 'modules/log-analytics.bicep' = {
  name: 'log-analytics-deployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
    applicationName: applicationName
    tags: commonTags
    retentionInDays: environmentName == 'prod' ? 90 : 30
    sku: 'PerGB2018'
  }
}

// Application Insights
module applicationInsightsModule 'modules/application-insights.bicep' = {
  name: 'application-insights-deployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
    applicationName: applicationName
    tags: commonTags
    logAnalyticsWorkspaceId: logAnalyticsModule.outputs.workspaceId
    applicationType: 'web'
  }
}

// Key Vault
module keyVaultModule 'modules/key-vault.bicep' = {
  name: 'key-vault-deployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
    applicationName: applicationName
    tags: commonTags
    deploymentPrincipalId: deploymentPrincipalId
    skuName: environmentName == 'prod' ? 'premium' : 'standard'
    softDeleteRetentionInDays: environmentName == 'prod' ? 30 : 7
  }
}

// Container Registry
module containerRegistryModule 'modules/container-registry.bicep' = {
  name: 'container-registry-deployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
    applicationName: applicationName
    tags: commonTags
    sku: environmentName == 'prod' ? 'Standard' : 'Basic'
    adminUserEnabled: false
  }
}

// PostgreSQL Flexible Server
module postgresModule 'modules/postgresql.bicep' = {
  name: 'postgresql-deployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
    applicationName: applicationName
    tags: commonTags
    administratorLogin: postgresAdminLogin
    administratorPassword: postgresAdminPassword
    skuName: environmentName == 'prod' ? 'Standard_B2s' : 'Standard_B1ms'
    storageSizeGB: environmentName == 'prod' ? 128 : 32
    enableHighAvailability: environmentName == 'prod'
    backupRetentionDays: environmentName == 'prod' ? 14 : 7
    keyVaultId: keyVaultModule.outputs.keyVaultId
    databaseName: 'todolistdb'
  }
}

// Container Apps Environment
module containerAppsEnvironmentModule 'modules/container-apps-environment.bicep' = {
  name: 'container-apps-environment-deployment'
  scope: resourceGroup
  params: {
    location: location
    environmentName: environmentName
    applicationName: applicationName
    tags: commonTags
    logAnalyticsWorkspaceId: logAnalyticsModule.outputs.workspaceId
    logAnalyticsWorkspaceKey: logAnalyticsModule.outputs.primarySharedKey
    enableWorkloadProfiles: false
  }
}

// Outputs
output resourceGroupName string = resourceGroup.name
output containerRegistryLoginServer string = containerRegistryModule.outputs.loginServer
output containerRegistryName string = containerRegistryModule.outputs.registryName
output keyVaultName string = keyVaultModule.outputs.keyVaultName
output keyVaultUri string = keyVaultModule.outputs.keyVaultUri
output postgresServerName string = postgresModule.outputs.serverName
output postgresServerFqdn string = postgresModule.outputs.serverFqdn
output databaseName string = postgresModule.outputs.databaseName
output containerAppEnvironmentName string = containerAppsEnvironmentModule.outputs.environmentName
output containerAppEnvironmentId string = containerAppsEnvironmentModule.outputs.environmentId
output applicationInsightsName string = applicationInsightsModule.outputs.applicationInsightsName
output applicationInsightsConnectionString string = applicationInsightsModule.outputs.connectionString
output logAnalyticsWorkspaceName string = logAnalyticsModule.outputs.workspaceName
