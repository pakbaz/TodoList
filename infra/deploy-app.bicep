@description('The location for all resources')
param location string = resourceGroup().location

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('The application name')
param applicationName string = 'todolist'

@description('Container Apps Environment ID')
param containerAppEnvironmentId string

@description('Container Registry login server')
param containerRegistryLoginServer string

@description('Container image name and tag')
param containerImage string

@description('Key Vault name')
param keyVaultName string

@description('Key Vault URI')
param keyVaultUri string

@description('Application Insights connection string')
param applicationInsightsConnectionString string

// Common tags for all resources
var commonTags = {
  Environment: environmentName
  Application: applicationName
  ManagedBy: 'Infrastructure as Code'
  Project: 'TodoList'
}

// Reference to existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Reference to existing Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: last(split(containerRegistryLoginServer, '.'))
}

// Store Application Insights connection string in Key Vault
resource appInsightsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'appinsights-connection-string'
  parent: keyVault
  properties: {
    value: applicationInsightsConnectionString
  }
}

// Deploy Container App
module containerAppModule 'modules/container-app.bicep' = {
  name: 'container-app-deployment'
  params: {
    location: location
    environmentName: environmentName
    applicationName: applicationName
    tags: commonTags
    containerAppEnvironmentId: containerAppEnvironmentId
    containerRegistryLoginServer: containerRegistryLoginServer
    containerImage: containerImage
    keyVaultUri: keyVaultUri
    enableIngress: true
    targetPort: 8080
    resources: {
      cpu: environmentName == 'prod' ? '1.0' : '0.5'
      memory: environmentName == 'prod' ? '2Gi' : '1Gi'
    }
    replicas: {
      min: environmentName == 'prod' ? 2 : 1
      max: environmentName == 'prod' ? 10 : 3
    }
  }
  dependsOn: [
    appInsightsConnectionStringSecret
  ]
}

// Role assignment for Container App managed identity to access Key Vault
resource containerAppKeyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('kv-secrets-user-role', environmentName, applicationName)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: containerAppModule.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment for Container App managed identity to pull from ACR
resource containerAppAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('acr-pull-role', environmentName, applicationName)
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: containerAppModule.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output containerAppId string = containerAppModule.outputs.containerAppId
output containerAppName string = containerAppModule.outputs.containerAppName
output containerAppFqdn string = containerAppModule.outputs.containerAppFqdn
output principalId string = containerAppModule.outputs.principalId
