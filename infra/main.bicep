@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Prefix used for resource names')
param namePrefix string = 'todolist'

@description('Environment name (dev/test/prod)')
param environment string = 'dev'

@description('Container image tag to deploy (e.g. commit SHA)')
param imageTag string = 'latest'

@description('PostgreSQL admin username (no @)')
@secure()
param pgAdminUser string

@description('PostgreSQL admin password')
@secure()
param pgAdminPassword string

@description('App insights app type')
param appInsightsType string = 'web'

@description('Container app cpu cores')
param appCpu int = 1

@description('Container app memory in GiB')
param appMemory string = '1Gi'

var acrName = '${namePrefix}${uniqueString(resourceGroup().id)}acr'
var kvName = '${namePrefix}-${environment}-kv'
var pgName = '${namePrefix}-${environment}-pg'
var logName = '${namePrefix}-${environment}-log'
var appInsightsName = '${namePrefix}-${environment}-ai'
var caEnvName = '${namePrefix}-${environment}-cae'
var appName = '${namePrefix}-${environment}-app'
var imageName = 'todolist'

// Log Analytics
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'logAnalytics'
  params: {
    location: location
    name: logName
  }
}

// App Insights
module appInsights 'modules/appinsights.bicep' = {
  name: 'appInsights'
  params: {
    location: location
    name: appInsightsName
    workspaceId: logAnalytics.outputs.workspaceId
    appType: appInsightsType
  }
}

// ACR
module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    location: location
    name: acrName
  }
}

// Key Vault
module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    name: kvName
    enableRbac: true
  }
}

// PostgreSQL Flexible Server
module postgres 'modules/postgres.bicep' = {
  name: 'postgres'
  params: {
    location: location
    name: pgName
    adminUser: pgAdminUser
  adminPassword: pgAdminPassword
  databaseName: 'todolistdb'
  }
}

// ACA Environment
module acaEnv 'modules/aca-environment.bicep' = {
  name: 'acaEnvironment'
  params: {
    location: location
    name: caEnvName
    workspaceId: logAnalytics.outputs.workspaceId
  }
}

// Container App with MI + Key Vault reference placeholder for DefaultConnection
module containerApp 'modules/containerapp.bicep' = {
  name: 'containerApp'
  params: {
    location: location
    name: appName
    environmentId: acaEnv.outputs.environmentId
    containerImage: '${acr.outputs.loginServer}/${imageName}:${imageTag}'
    targetPort: 8080
    cpu: appCpu
    memory: appMemory
    registryServer: acr.outputs.loginServer
    // Note: username/password not needed if using managed identity and ACR RBAC pull
    keyVaultId: keyvault.outputs.vaultId
  appInsightsConnectionString: appInsights.outputs.connectionString
  }
}

// Existing resource handles for scoped role assignments
resource acrRes 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource kvRes 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: kvName
}

// Role assignment: allow Container App system-assigned identity to pull from ACR
resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, 'AcrPull', acrName, appName)
  scope: acrRes
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: containerApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: allow Container App system-assigned identity to read secrets from Key Vault
resource kvSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, 'KVSecretsUser', kvName, appName)
  scope: kvRes
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: containerApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs for CI usage
output acrLoginServer string = acr.outputs.loginServer
output acrName string = acrName
output containerAppName string = appName
output containerAppFqdn string = containerApp.outputs.fqdn
output keyVaultName string = kvName
output keyVaultId string = keyvault.outputs.vaultId
output postgresFqdn string = postgres.outputs.fqdn
