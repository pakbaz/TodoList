@description('Deployment environment (e.g., dev, staging, prod)')
param env string = 'dev'

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Admin username for PostgreSQL')
param postgresAdminUser string = 'pgadmin'

@secure()
@description('Admin password for PostgreSQL (if empty, auto-generated)')
param postgresAdminPassword string = ''

@description('SKU name for PostgreSQL Flexible Server (e.g., B_Standard_B1ms)')
param postgresSkuName string = 'B_Standard_B1ms'

@description('App Service Plan SKU (tier)')
param appServiceSkuName string = 'B1'

@description('App Service Plan SKU tier')
param appServiceSkuTier string = 'Basic'

@description('Container image tag (e.g., latest or sha)')
param imageTag string = 'latest'

@description('Container image repository (loginServer/repository)')
param imageRepo string

@description('Enable Application Insights (currently always deployed for simplicity)')
param enableAppInsights bool = true

var tags = {
  project: 'todolist'
  env: env
  repository: 'github.com/pakbaz/TodoList'
  createdBy: 'iac'
}

// Generate password if not provided
var generatedPassword = uniqueString(resourceGroup().id, env, postgresAdminUser)
// Bicep requires interpolation. Ensure password meets complexity.
var effectivePassword = empty(postgresAdminPassword) ? '${generatedPassword}Aa1!' : postgresAdminPassword

module postgres 'modules/postgres.bicep' = {
  name: 'postgres-${env}'
  params: {
    location: location
    adminUser: postgresAdminUser
    adminPassword: effectivePassword
    skuName: postgresSkuName
    env: env
    tags: tags
  }
}

module keyvault 'modules/keyvault.bicep' = if (env != 'dev') {
  name: 'kv-${env}'
  params: {
    location: location
    env: env
    tags: tags
    postgresAdminPassword: effectivePassword
  }
}

module appInsights 'modules/appinsights.bicep' = {
  name: 'appi-${env}'
  params: {
    location: location
    env: env
    tags: tags
  }
}

var appInsightsConn = enableAppInsights ? appInsights.outputs.connectionString : ''

module app 'modules/app.bicep' = {
  name: 'app-${env}'
  params: {
    location: location
    env: env
    skuName: appServiceSkuName
    skuTier: appServiceSkuTier
    imageTag: imageTag
    imageRepo: imageRepo
  connectionString: 'Host=${postgres.outputs.host};Database=${postgres.outputs.databaseName};Username=${postgresAdminUser};Password=${effectivePassword}'
  appInsightsConnectionString: appInsightsConn
    tags: tags
  }
}

output postgresServerName string = postgres.outputs.serverName
output postgresDatabase string = postgres.outputs.databaseName
output webAppName string = app.outputs.webAppName
output appServicePlanName string = app.outputs.planName
