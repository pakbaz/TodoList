@description('Application name prefix used for resource naming')
param applicationName string = 'todolist'

@description('Environment suffix (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Azure region for resource deployment')
param location string = resourceGroup().location

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('Resource tags to apply to all resources')
param tags object = {
  Application: applicationName
  Environment: environment
  DeployedBy: 'Bicep'
}

// Variables for resource naming
var resourceSuffix = '${applicationName}-${environment}-${substring(uniqueString(resourceGroup().id), 0, 6)}'
var vnetName = 'vnet-${resourceSuffix}'
var keyVaultName = 'kv-${substring(replace(resourceSuffix, '-', ''), 0, 24)}'
var containerRegistryName = 'acr${substring(replace(resourceSuffix, '-', ''), 0, 20)}'
var postgresServerName = 'psql-${resourceSuffix}'
var databaseName = 'todolistdb'
var containerAppEnvironmentName = 'cae-${resourceSuffix}'
var containerAppName = 'ca-${resourceSuffix}'
var logAnalyticsName = 'law-${resourceSuffix}'
var appInsightsName = 'ai-${resourceSuffix}'
var managedIdentityName = 'mi-${resourceSuffix}'

// Network module
module networking 'modules/network.bicep' = {
  name: 'network-deployment'
  params: {
    vnetName: vnetName
    location: location
    tags: tags
    environment: environment
  }
}

// Monitoring Module
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
    location: location
    tags: tags
    environment: environment
  }
}

// Key Vault Module
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    keyVaultName: keyVaultName
    location: location
    tags: tags
    environment: environment
    vnetId: networking.outputs.vnetId
    subnetId: networking.outputs.privateEndpointSubnetId
  }
}

// Container Registry Module
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry-deployment'
  params: {
    containerRegistryName: containerRegistryName
    location: location
    tags: tags
    environment: environment
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// PostgreSQL Module
module postgresql 'modules/postgresql.bicep' = {
  name: 'postgresql-deployment'
  params: {
    postgresServerName: postgresServerName
    databaseName: databaseName
    location: location
    tags: tags
    environment: environment
    databaseSubnetId: networking.outputs.databaseSubnetId
    privateDnsZoneId: networking.outputs.postgresqlPrivateDnsZoneId
    keyVaultId: keyVault.outputs.keyVaultId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    administratorLoginPassword: postgresAdminPassword
  }
}

// Managed Identity for Container Apps
resource containerAppManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

// ACR Pull Role Assignment for Managed Identity
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, containerAppManagedIdentity.id, 'AcrPull')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: containerAppManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    containerRegistry
  ]
}

// Secrets Management Module
module secrets 'modules/secrets.bicep' = {
  name: 'secrets-deployment'
  params: {
    keyVaultName: keyVaultName
    managedIdentityId: containerAppManagedIdentity.id
    managedIdentityPrincipalId: containerAppManagedIdentity.properties.principalId
    postgresAdminPassword: postgresAdminPassword
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    postgresConnectionString: 'Host=${postgresql.outputs.postgresServerFqdn};Database=${databaseName};Username=${postgresql.outputs.administratorLogin};Password=${postgresAdminPassword};SSL Mode=Require;Trust Server Certificate=true'
    environment: environment
  }
}

// Container Apps Module
module containerApps 'modules/container-apps.bicep' = {
  name: 'container-apps-deployment'
  params: {
    containerAppEnvironmentName: containerAppEnvironmentName
    containerAppName: containerAppName
    location: location
    tags: tags
    environment: environment
    containerAppsSubnetId: networking.outputs.containerAppSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    containerRegistryLoginServer: containerRegistry.outputs.containerRegistryLoginServer
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    keyVaultUri: keyVault.outputs.keyVaultUri
    managedIdentityId: containerAppManagedIdentity.id
    databaseConnectionStringSecretUri: secrets.outputs.databaseConnectionUri
  }
  dependsOn: [
    acrPullRoleAssignment
  ]
}

// Outputs
@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name

@description('Virtual Network Name')
output vnetName string = networking.outputs.vnetName

@description('Key Vault Name')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('Container Registry Name')
output containerRegistryName string = containerRegistry.outputs.containerRegistryName

@description('Container Registry Login Server')
output containerRegistryLoginServer string = containerRegistry.outputs.containerRegistryLoginServer

@description('PostgreSQL Server FQDN')
output postgresServerFqdn string = postgresql.outputs.postgresServerFqdn

@description('Database Name')
output databaseName string = postgresql.outputs.databaseName

@description('Container App Name')
output containerAppName string = containerApps.outputs.containerAppName

@description('Container App FQDN')
output containerAppFqdn string = containerApps.outputs.containerAppFqdn

@description('Container App URL')
output containerAppUrl string = containerApps.outputs.containerAppUrl

@description('Log Analytics Workspace Name')
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName

@description('Application Insights Name')
output appInsightsName string = monitoring.outputs.appInsightsName

@description('Application Insights Connection String')
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

@description('Managed Identity ID')
output managedIdentityId string = containerAppManagedIdentity.id

@description('Managed Identity Principal ID')
output managedIdentityPrincipalId string = containerAppManagedIdentity.properties.principalId
