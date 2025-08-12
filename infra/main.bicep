// Main Bicep template for TodoList infrastructure
// This template orchestrates the deployment of all Azure resources

targetScope = 'resourceGroup'

// Parameters
@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Application name')
param applicationName string = 'todolist'

@description('Location for all resources')
param location string = resourceGroup().location

@description('PostgreSQL administrator login')
param postgresAdminLogin string = 'todolistadmin'

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('Container image name')
param containerImage string = 'todolist-app:latest'

@description('Log Analytics workspace retention in days')
param logRetentionInDays int = 30

@description('Database SKU name')
param databaseSkuName string = environment == 'prod' ? 'Standard_D4s_v3' : (environment == 'staging' ? 'Standard_D2s_v3' : 'Standard_B1ms')

@description('Database storage size in GB')
param databaseStorageSizeGB int = environment == 'prod' ? 128 : (environment == 'staging' ? 64 : 32)

@description('Enable high availability for database')
param enableDatabaseHA bool = environment == 'prod'

@description('Enable zone redundancy for container apps environment')
param enableZoneRedundancy bool = environment == 'prod'

@description('Minimum replicas for container app')
param minReplicas int = environment == 'prod' ? 2 : (environment == 'staging' ? 1 : 0)

@description('Maximum replicas for container app')
param maxReplicas int = environment == 'prod' ? 10 : (environment == 'staging' ? 5 : 3)

// Variables
var resourcePrefix = '${applicationName}-${environment}'
var tags = {
  environment: environment
  application: applicationName
  deployedBy: 'bicep'
}

// Log Analytics Workspace
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics-deployment'
  params: {
    workspaceName: '${resourcePrefix}-logs'
    location: location
    retentionInDays: logRetentionInDays
    tags: tags
  }
}

// Application Insights
module appInsights 'modules/app-insights.bicep' = {
  name: 'app-insights-deployment'
  params: {
    appInsightsName: '${resourcePrefix}-ai'
    location: location
    workspaceResourceId: logAnalytics.outputs.workspaceId
    tags: tags
  }
}

// Key Vault
module keyVault 'modules/key-vault.bicep' = {
  name: 'key-vault-deployment'
  params: {
    keyVaultName: '${resourcePrefix}-kv-${uniqueString(resourceGroup().id)}'
    location: location
    tags: tags
  }
}

// Container Registry
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry-deployment'
  params: {
    registryName: '${replace(resourcePrefix, '-', '')}acr${uniqueString(resourceGroup().id)}'
    location: location
    tags: tags
  }
}

// PostgreSQL Database
module postgresql 'modules/postgresql.bicep' = {
  name: 'postgresql-deployment'
  params: {
    serverName: '${resourcePrefix}-db'
    location: location
    administratorLogin: postgresAdminLogin
    administratorPassword: postgresAdminPassword
    skuName: databaseSkuName
    storageSizeGB: databaseStorageSizeGB
    enableHighAvailability: enableDatabaseHA
    tags: tags
  }
}

// Container Apps Environment
module containerAppsEnv 'modules/container-apps-env.bicep' = {
  name: 'container-apps-env-deployment'
  params: {
    environmentName: '${resourcePrefix}-env'
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    zoneRedundant: enableZoneRedundancy
    tags: tags
  }
}

// Store secrets in Key Vault
module secrets 'modules/key-vault-secrets.bicep' = {
  name: 'key-vault-secrets-deployment'
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    secrets: [
      {
        name: 'ConnectionStrings--DefaultConnection'
        value: 'Host=${postgresql.outputs.serverFqdn};Database=todolistdb;Username=${postgresAdminLogin};Password=${postgresAdminPassword};SSL Mode=Require'
      }
      {
        name: 'ApplicationInsights--ConnectionString'
        value: appInsights.outputs.connectionString
      }
    ]
  }
}

// Container App
module containerApp 'modules/container-app.bicep' = {
  name: 'container-app-deployment'
  params: {
    appName: '${resourcePrefix}-app'
    location: location
    environmentId: containerAppsEnv.outputs.environmentId
    containerImage: containerImage
    registryServer: containerRegistry.outputs.registryServer
    keyVaultName: keyVault.outputs.keyVaultName
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    tags: tags
  }
  dependsOn: [
    secrets
  ]
}

// RBAC assignments for Container App managed identity
module rbacAssignments 'modules/rbac-assignments.bicep' = {
  name: 'rbac-assignments-deployment'
  params: {
    principalId: containerApp.outputs.principalId
    keyVaultId: keyVault.outputs.keyVaultId
    registryId: containerRegistry.outputs.registryId
  }
}

// Outputs
output resourceGroupName string = resourceGroup().name
output containerAppUrl string = containerApp.outputs.appUrl
output containerRegistryName string = containerRegistry.outputs.registryName
output containerRegistryServer string = containerRegistry.outputs.registryServer
output databaseServerName string = postgresql.outputs.serverName
output databaseServerFqdn string = postgresql.outputs.serverFqdn
output keyVaultName string = keyVault.outputs.keyVaultName
output keyVaultUri string = keyVault.outputs.keyVaultUri
output applicationInsightsName string = appInsights.outputs.appInsightsName
output logAnalyticsWorkspaceName string = logAnalytics.outputs.workspaceName
output containerAppPrincipalId string = containerApp.outputs.principalId
