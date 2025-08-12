// The main orchestrator for TodoList application infrastructure

targetScope = 'resourceGroup'

// Parameters
@description('Application name - used as a prefix for all resources')
param appName string = 'todolist'

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Container image tag to deploy')
param imageTag string = 'latest'

@description('Azure Container Registry name')
param acrName string = '${appName}acr${environment}'

@description('PostgreSQL administrator username')
param postgresqlAdminLogin string = 'todolistadmin'

@description('PostgreSQL administrator password')
@secure()
param postgresqlAdminPassword string

@description('Resource tags to apply to all resources')
param tags object = {
  application: appName
  environment: environment
  'managed-by': 'bicep'
}

// Variables
var keyVaultName = take('${appName}-kv-${environment}-${uniqueString(resourceGroup().id)}', 24)
var logAnalyticsName = '${appName}-logs-${environment}'
var postgresqlServerName = '${appName}-db-${environment}'
var acaEnvironmentName = '${appName}-env-${environment}'
var acaAppName = '${appName}-app-${environment}'

// Module: Log Analytics Workspace
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'logAnalytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
}

// Module: Azure Key Vault
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVault'
  params: {
    name: keyVaultName
    location: location
    tags: tags
  }
}

// Module: Azure Container Registry
module containerRegistry 'modules/acr.bicep' = {
  name: 'containerRegistry'
  params: {
    name: acrName
    location: location
    tags: tags
  }
}

// Module: PostgreSQL Flexible Server
module postgresql 'modules/postgresql.bicep' = {
  name: 'postgresql'
  params: {
    serverName: postgresqlServerName
    location: location
    administratorLogin: postgresqlAdminLogin
    administratorPassword: postgresqlAdminPassword
    keyVaultName: keyVault.outputs.name
    tags: tags
  }
}

// Module: Container Apps Environment
module acaEnvironment 'modules/aca-env.bicep' = {
  name: 'acaEnvironment'
  params: {
    name: acaEnvironmentName
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: tags
  }
}

// Module: Container App
module containerApp 'modules/aca-app.bicep' = {
  name: 'containerApp'
  params: {
    name: acaAppName
    location: location
    environment: environment
    containerAppsEnvironmentId: acaEnvironment.outputs.id
    containerRegistryName: containerRegistry.outputs.name
    imageTag: imageTag
    keyVaultName: keyVault.outputs.name
    managedIdentityId: containerRegistry.outputs.managedIdentityId
    tags: tags
  }
}

// Outputs
@description('The URL of the deployed application')
output applicationUrl string = containerApp.outputs.applicationUrl

@description('The name of the Container Apps Environment')
output acaEnvironmentName string = acaEnvironment.outputs.name

@description('The name of the Container App')
output acaAppName string = containerApp.outputs.name

@description('The name of the Azure Container Registry')
output acrName string = containerRegistry.outputs.name

@description('The name of the PostgreSQL server')
output postgresqlServerName string = postgresql.outputs.serverName

@description('The name of the Key Vault')
output keyVaultName string = keyVault.outputs.name

@description('The name of the Log Analytics workspace')
output logAnalyticsWorkspaceName string = logAnalytics.outputs.name
